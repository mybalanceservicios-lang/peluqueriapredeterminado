// Función de backend: genera un cobro de Mercado Pago (Checkout Pro) y lo deja
// registrado como "pendiente" en la tabla cobros_mp.
//
// El token de Mercado Pago NO es un secreto fijo de esta función — es el que cada
// negocio pegó desde Configuración → "Conectar Mercado Pago" (queda guardado en
// config_mp, una tabla que el navegador puede escribir pero nunca volver a leer).
// Esta función sí puede leerlo porque usa la service role key, que nunca sale del
// servidor. Así, el mismo código sirve para cualquier cliente que use esta plantilla —
// lo único que cambia entre un negocio y otro es el token que cada uno cargó.
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
    const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Cliente que actúa COMO quien llama (reenvía su sesión) — así las políticas de RLS
    // deciden si puede o no generar un cobro, no esta función.
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) return json({ error: "Sesión inválida" }, 401);

    // Acá sí hace falta la service role: config_mp no tiene policy de select para nadie.
    const supabaseAdmin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
    const { data: cfg } = await supabaseAdmin.from("config_mp").select("mp_access_token").eq("id", "default").maybeSingle();
    const MP_ACCESS_TOKEN = cfg?.mp_access_token;
    if (!MP_ACCESS_TOKEN) {
      return json({ error: "Mercado Pago todavía no está conectado. Pedile al dueño que lo conecte desde Configuración." }, 400);
    }

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
      return json({ error: "No se pudo crear el cobro en Mercado Pago. Revisá que el token conectado sea válido." }, 502);
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
