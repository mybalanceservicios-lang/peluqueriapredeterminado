# Plantilla predeterminada — Gestión de Barbería

Sistema de gestión para barberías: `index.html` (privado, para el dueño y barberos, con login real) + `reservar.html` (público, para que un cliente reserve turno, sin login). Sirve como base para ofrecer a barberías clientas: se clona/copia y se personaliza (nombre, logo, precios, barberos) por cliente.

## Cómo probarla
Abrí `index.html` en el navegador para el sistema de gestión (pide iniciar sesión), y `reservar.html` para la página de reservas (pública, sin login). Turnos, configuración del negocio (horario, servicios visibles, barberos), clientes y accesos se sincronizan con Supabase — ver "Backend" abajo. El resto de los datos (servicios cargados, ventas, gastos, cierres) todavía vive solo en `localStorage` de ese dispositivo.

## Backend (Supabase)
`supabase-schema.sql` tiene el SQL para crear las tablas `config` (datos del negocio), `turnos`, `clientes` (nombre + teléfono, para poder mandar recordatorios), `perfiles` (quién es dueño y quién es cada barbero) e `invitaciones` (códigos de acceso). Hay que:
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. Pegar y ejecutar `supabase-schema.sql` en el SQL Editor del proyecto (si ya tenías una versión vieja de estas tablas, usá el bloque de migración que corresponda al final del mismo archivo, según de qué versión vengas).
3. Reemplazar `SUPABASE_URL` y `SUPABASE_ANON_KEY` (la "publishable key", nunca la "secret key") al principio del script de `index.html` y de `reservar.html`.
4. En Authentication → Providers → Email, dejar **activado** "Allow new users to sign up". Esto no es un descuido: cualquiera puede crear una cuenta desde la app, pero sin un código de invitación válido esa cuenta no puede hacer nada (no tiene perfil asignado, y las políticas de la base no le dan ningún permiso sin perfil).
5. El primer dueño entra a `index.html`, toca "Todavía no tengo acceso — crear cuenta", crea su mail + clave, y en la pantalla siguiente toca "¿Sos el dueño y es la primera vez que se usa este sistema? Entrar sin código" — esto solo funciona una vez, mientras el sistema no tenga ningún dueño todavía.

## Login y accesos (por código de invitación, sin tocar Supabase)
Nadie necesita entrar al panel de Supabase para dar de alta a un barbero — todo se hace desde adentro de `index.html`:

1. El dueño, logueado, va a Configuración → "Invitar a un barbero", pone el nombre y genera un código (algo como `AB3D-EFGH`).
2. Le pasa ese código al barbero por el medio que quiera (WhatsApp, en persona, etc.).
3. El barbero entra a `index.html`, toca "Todavía no tengo acceso — crear cuenta", elige su propio mail y clave.
4. En la pantalla siguiente, pone el código que le dio el dueño. El sistema valida que el código exista y no esté usado, y le asigna automáticamente el rol que el dueño definió al crearlo (no puede elegir "ser dueño" con un código de barbero).
5. De ahí en más, ese barbero entra directo a su vista con su mail y clave, desde cualquier dispositivo.

Un código sirve una sola vez. El dueño puede ver el estado de cada código (pendiente/usado) y la lista de accesos actuales desde esa misma pantalla de Configuración.

`reservar.html` (la página pública de turnos) NO requiere login — sigue siendo de acceso libre para que cualquier cliente pueda reservar, como corresponde.

## Qué incluye
Para el dueño, la navegación está organizada en 3 secciones:

- **Web virtual** — configuración de horario de atención, qué servicios mostrar, vista previa de la vidriera online, y texto listo para compartir por WhatsApp/Instagram. Desde acá hay un link a `reservar.html`, que ya funciona de verdad entre dispositivos distintos (un turno reservado desde un celular aparece en la Agenda de otra compu). El teléfono es obligatorio para reservar, y tiene una protección básica anti-abuso (bloquea si un mismo número ya tiene 3+ turnos pendientes sin usar, más un campo "honeypot" contra bots).
- **Agenda** — turnos con detección de choques de horario, teléfono opcional al cargar a mano, y un botón de WhatsApp por turno para mandar un recordatorio con mensaje pre-armado. Al marcar un turno como "Atendido" (eligiendo el medio de pago), se genera automáticamente el corte correspondiente en Finanzas — no hace falta cargarlo dos veces. Los registros vinculados muestran una etiqueta "Vinculado". Un botón "Actualizar" trae los turnos y clientes desde la web.
- **Finanzas** — Panel (KPIs y gráficos), Cargar (cortes/productos), Servicios, Gráficos, Cierre de caja diario (registro inmutable por día con historial y exportación a CSV listo para Excel), Clientes (nombre + teléfono guardados automáticamente al reservar, con botón de WhatsApp), Barberos y comisiones, Precios, Gastos y sueldos, Stock.

Configuración (nombre, logo, sesión, invitar barberos, accesos, respaldo JSON) accesible desde el ícono de engranaje junto al perfil.

## Cobrar con Mercado Pago (QR, confirmación automática)
Al cargar un corte o una venta, elegir "Mercado Pago" como medio de pago muestra un botón "Cobrar con Mercado Pago" en vez de cargar directo: genera un QR real (Checkout Pro) y el corte/venta queda **pendiente** — recién se carga solo, sin tocar nada, cuando Mercado Pago confirma que el cliente pagó.

**Importante para quien vende/administra esta plantilla a varios negocios**: el Access Token de Mercado Pago NO se configura por archivo ni por CLI — cada negocio pega el suyo propio desde adentro de la app (Configuración → "Conectar Mercado Pago"), así los cobros le llegan a SU cuenta. Las dos funciones de backend (Edge Functions) se despliegan **una sola vez por proyecto de Supabase**, al armar el sistema de cada cliente — después de eso, conectar, cambiar o reconectar el Mercado Pago de ese negocio es 100% self-service, sin volver a tocar la terminal:

1. Instalar la [CLI de Supabase](https://supabase.com/docs/guides/cli) y hacer login (`supabase login`), vincular el proyecto (`supabase link --project-ref TU_PROJECT_REF` — el ref está en la URL del proyecto en el dashboard).
2. Desplegar las dos funciones (esto es todo lo que hace falta por consola, una vez por proyecto — no llevan secretos propios, así que no hace falta `supabase secrets set`):
   ```
   supabase functions deploy crear-pago-mp
   supabase functions deploy webhook-mp --no-verify-jwt
   ```
   (`webhook-mp` va sin verificación de JWT porque la llama Mercado Pago, no un usuario logueado de la app — su seguridad es la firma, no un token de Supabase.)
3. Correr (si no lo corriste ya) el bloque de `cobros_mp` + `config_mp` de `supabase-schema.sql` — crea las tablas, sus políticas, y habilita `cobros_mp` para Realtime (así el navegador se entera solo, al instante, cuando se confirma un pago).

De ahí en más, el **dueño de cada negocio** hace esto desde la app, sin ayuda técnica:
1. Entra a [mercadopago.com.ar/developers/panel](https://www.mercadopago.com.ar/developers/panel) con SU cuenta de Mercado Pago, crea una aplicación, y copia el **Access Token de producción** (en "Credenciales de producción") y la **clave de firma del webhook** (en la sección "Webhooks" de esa misma aplicación).
2. En esa sección de Webhooks de Mercado Pago, pega como URL de notificaciones la que el sistema le muestra en Configuración → "Conectar Mercado Pago" (botón "Copiar").
3. Vuelve a `index.html`, va a Configuración → "Conectar Mercado Pago", pega el Access Token y la clave de firma, y toca "Conectar".

El token queda guardado en una tabla (`config_mp`) que **ni el dueño ni nadie puede volver a leer desde el navegador** una vez guardado — solo las dos funciones de backend pueden leerlo (usan la service role key, que nunca sale del servidor). Si el dueño necesita cambiarlo, simplemente pega uno nuevo y lo pisa. Mientras no esté conectado, el botón de Mercado Pago avisa que falta conectarlo — el resto del sistema sigue funcionando normal.

**Antes de usarlo con cobros reales**: la verificación de firma del webhook (`supabase/functions/webhook-mp/index.ts`) está armada siguiendo el esquema que documenta Mercado Pago, pero no se pudo probar contra la API real de Mercado Pago desde este entorno (sin acceso a internet para eso). Antes de cobrar en serio, hacé una prueba con un pago chico de verdad y confirmá en los logs de la función (`supabase functions logs webhook-mp`) que la firma se valida bien y el corte se carga solo.

## Estado
Sistema con reservas online conectadas a un backend real (Supabase), login real por mail para el personal (con alta de nuevos accesos por código de invitación, sin tocar el panel de Supabase), y cobro con Mercado Pago con confirmación automática — ya en condiciones de usarse con una barbería real, siguiendo los pasos de "Backend" de arriba. El resto del sistema (servicios, ventas, gastos, cierres) sigue siendo 100% local por dispositivo por ahora — no se sincroniza entre celular y compu.

### Si el proyecto de Supabase ya venía de una versión anterior
`supabase-schema.sql` tiene, al final, un bloque de migración para cada caso: si venías de la versión "de prueba" (políticas abiertas, sin login) o de una versión intermedia con login por mail pero sin invitaciones. Reemplazá las políticas indicadas y corré la función/trigger de invitaciones — sin eso, el sistema de códigos no funciona.
