// Webhook de Mercado Pago: lo llama Mercado Pago (NO el navegador) cada vez que cambia
// el estado de un pago. Es la ÚNICA puerta por la que un cobro puede pasar a "aprobado" —
// el navegador no tiene (ni puede tener) permiso para marcarlo él mismo, así que incluso
// si alguien manipulara la app desde las herramientas de desarrollador, no podría
// "inventar" un pago.
//
// El Access Token y la clave de webhook NO son secretos fijos de esta función — son los
// que el dueño de este negocio puntual pegó desde Configuración → "Conectar Mercado Pago"
// (guardados en config_mp, con la service role key como única forma de leerlos). El mismo
// código de esta función sirve para cualquier cliente que use esta plantilla.
//
// Dos verificaciones antes de confiar en cualquier cosa:
// 1. La firma (x-signature) tiene que coincidir con la clave de webhook guardada en
//    config_mp — así sabemos que el aviso realmente vino de Mercado Pago.
// 2. Aun con la firma OK, no confiamos en el estado que venga en el cuerpo del aviso —
//    le volvemos a preguntar a la API de Mercado Pago el estado real de ESE pago puntual.
//
// Importante: esta función hay que desplegarla SIN verificación de JWT
// (supabase functions deploy webhook-mp --no-verify-jwt), porque Mercado Pago la llama
// sin ningún token de Supabase — la seguridad acá la da la firma, no un JWT.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  // Mercado Pago no espera nada elaborado: siempre devolvemos 200 salvo que la firma
  // esté mal (ahí sí rechazamos), para que no reintente en loop por errores nuestros.
  try {
    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: cfg } = await supabaseAdmin.from("config_mp").select("mp_access_token, mp_webhook_secret").eq("id", "default").maybeSingle();
    const MP_ACCESS_TOKEN = cfg?.mp_access_token;
    const MP_WEBHOOK_SECRET = cfg?.mp_webhook_secret;
    if (!MP_ACCESS_TOKEN || !MP_WEBHOOK_SECRET) {
      console.error("Mercado Pago no está conectado (falta token o clave de webhook en config_mp)");
      return new Response("ok", { status: 200 });
    }

    const url = new URL(req.url);
    const body = await req.json().catch(() => ({} as any));
    const paymentId = body?.data?.id || url.searchParams.get("data.id") || url.searchParams.get("id");
    if (!paymentId) return new Response("ok", { status: 200 }); // nada que procesar

    // --- 1) Verificar la firma ---
    const xSignature = req.headers.get("x-signature") || "";
    const xRequestId = req.headers.get("x-request-id") || "";
    const partes: Record<string, string> = {};
    xSignature.split(",").forEach((p) => {
      const [k, v] = p.split("=");
      if (k && v) partes[k.trim()] = v.trim();
    });
    const ts = partes["ts"];
    const v1 = partes["v1"];
    if (!ts || !v1) return new Response("falta firma", { status: 401 });

    const manifest = `id:${paymentId};request-id:${xRequestId};ts:${ts};`;
    const esperado = await hmacSha256Hex(MP_WEBHOOK_SECRET, manifest);
    if (esperado !== v1) {
      console.error("Firma de Mercado Pago inválida");
      return new Response("firma inválida", { status: 401 });
    }

    // --- 2) Preguntarle a Mercado Pago el estado real de este pago ---
    const payRes = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    });
    if (!payRes.ok) return new Response("ok", { status: 200 });
    const pago = await payRes.json();

    if (pago.status === "approved" && pago.external_reference) {
      const { data: cobro } = await supabaseAdmin
        .from("cobros_mp")
        .select("*")
        .eq("id", pago.external_reference)
        .maybeSingle();
      // idempotencia: si ya estaba aprobado (Mercado Pago puede reenviar el mismo aviso
      // varias veces), no hacemos nada de nuevo.
      if (cobro && cobro.estado === "pendiente") {
        await supabaseAdmin
          .from("cobros_mp")
          .update({ estado: "aprobado", mp_payment_id: String(pago.id), confirmado_en: new Date().toISOString() })
          .eq("id", pago.external_reference);
      }
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error("Error inesperado en webhook-mp:", e);
    return new Response("ok", { status: 200 });
  }
});
