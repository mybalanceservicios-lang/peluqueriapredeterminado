// Función de backend: genera un cobro de Mercado Pago (Checkout Pro) y lo deja
// registrado como "pendiente" en la tabla cobros_mp. El navegador NUNCA ve ni toca
// el token de Mercado Pago — ese token vive solo acá, como secreto de esta función
// (ver "supabase secrets set MP_ACCESS_TOKEN=..." en el README).
//
// Quién puede llamar esta función: cualquier persona logueada con un perfil asignado
// (dueño o barbero real) — se verifica reenviando su JWT a Supabase y dejando que las
// políticas de RLS de cobros_mp hagan el resto (solo alguien con perfil puede insertar).
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "No autorizado" }, 401);

    const { monto, concepto } = await req.json();
    const montoNum = Number(monto);
    if (!montoNum || montoNum <= 0) return json({ error: "Monto inválido" }, 400);

    const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
    const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
    const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN");
    if (!MP_ACCESS_TOKEN) return json({ error: "Mercado Pago no está configurado en este servidor (falta MP_ACCESS_TOKEN)." }, 500);

    // Cliente que actúa COMO quien llama (reenvía su sesión) — así las políticas de RLS
    // deciden si puede o no generar un cobro, no esta función.
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Sesión inválida" }, 401);

    const cobroId = crypto.randomUUID();

    const prefRes = await fetch("https://api.mercadopago.com/checkout/preferences", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
      body: JSON.stringify({
        items: [{ title: concepto || "Cobro", quantity: 1, unit_price: montoNum, currency_id: "ARS" }],
        external_reference: cobroId,
        notification_url: `${SUPABASE_URL}/functions/v1/webhook-mp`,
      }),
    });
    if (!prefRes.ok) {
      const detalle = await prefRes.text();
      console.error("Error de Mercado Pago al crear preferencia:", detalle);
      return json({ error: "No se pudo crear el cobro en Mercado Pago" }, 502);
    }
    const pref = await prefRes.json();

    const { error: insertError } = await supabase.from("cobros_mp").insert({
      id: cobroId,
      monto: montoNum,
      concepto: concepto || null,
      estado: "pendiente",
      mp_preference_id: pref.id,
      creado_por: user.id,
    });
    if (insertError) {
      console.error("Error al guardar cobros_mp:", insertError.message);
      return json({ error: "No se pudo registrar el cobro" }, 500);
    }

    return json({ id: cobroId, initPoint: pref.init_point });
  } catch (e) {
    console.error("Error inesperado en crear-pago-mp:", e);
    return json({ error: "Error inesperado" }, 500);
  }
});
