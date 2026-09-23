# Plantilla predeterminada — Gestión de Barbería

Sistema de gestión para barberías: `index.html` (privado, para el dueño y barberos, con login real) + `reservar.html` (público, para que un cliente reserve turno, sin login). Sirve como base para ofrecer a barberías clientas: se clona/copia y se personaliza (nombre, logo, precios, barberos) por cliente.

## Cómo probarla
Abrí `index.html` en el navegador para el sistema de gestión (pide iniciar sesión), y `reservar.html` para la página de reservas (pública, sin login). Turnos, configuración del negocio (horario, servicios visibles, barberos), clientes y perfiles de acceso se sincronizan con Supabase — ver "Backend" abajo. El resto de los datos (servicios cargados, ventas, gastos, cierres) todavía vive solo en `localStorage` de ese dispositivo.

## Backend (Supabase)
`supabase-schema.sql` tiene el SQL para crear las tablas `config` (datos del negocio), `turnos`, `clientes` (nombre + teléfono, para poder mandar recordatorios) y `perfiles` (quién es dueño y quién es cada barbero). Hay que:
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. Pegar y ejecutar `supabase-schema.sql` en el SQL Editor del proyecto (si ya tenías una versión vieja de estas tablas con políticas abiertas, usá en cambio el bloque de migración que está al final del mismo archivo).
3. Reemplazar `SUPABASE_URL` y `SUPABASE_ANON_KEY` (la "publishable key", nunca la "secret key") al principio del script de `index.html` y de `reservar.html`.
4. En Authentication → Providers → Email, **desactivar "Allow new users to sign up"**. Esto es clave: sin este paso, cualquiera podría crearse una cuenta propia llamando directo a la API de Supabase, sin pasar por la app.
5. Para darle acceso a alguien (el dueño, un barbero), andá a Authentication → Users → Add user y creale un mail + clave. Pasáselos — la primera vez que esa persona entre a `index.html`, va a elegir si es el dueño o qué barbero es, y el sistema se lo va a recordar de ahí en más (en cualquier dispositivo).

## Login y accesos
`index.html` ahora pide iniciar sesión con mail y clave (Supabase Auth) antes de mostrar nada — no hay más selector de perfil libre ni PIN local. Cada persona tiene su propia cuenta (creada por el dueño desde el panel de Supabase, como se explica arriba). La primera vez que alguien entra con una cuenta nueva, elige si es "Dueño" o qué barbero es; después de eso entra directo a su vista. El dueño puede ver y quitar accesos desde Configuración → "Accesos (login por mail)".

`reservar.html` (la página pública de turnos) NO requiere login — sigue siendo de acceso libre para que cualquier cliente pueda reservar, como corresponde.

## Qué incluye
Para el dueño, la navegación está organizada en 3 secciones:

- **🌐 Web virtual** — configuración de horario de atención, qué servicios mostrar, vista previa de la vidriera online, y texto listo para compartir por WhatsApp/Instagram. Desde acá hay un link a `reservar.html`, que ya funciona de verdad entre dispositivos distintos (un turno reservado desde un celular aparece en la Agenda de otra compu). El teléfono es obligatorio para reservar, y tiene una protección básica anti-abuso (bloquea si un mismo número ya tiene 3+ turnos pendientes sin usar, más un campo "honeypot" contra bots).
- **🗓 Agenda** — turnos con detección de choques de horario, teléfono opcional al cargar a mano, y un botón "💬 WhatsApp" por turno para mandar un recordatorio con mensaje pre-armado. Al marcar un turno como "Atendido" (eligiendo el medio de pago), se genera automáticamente el corte correspondiente en Finanzas — no hace falta cargarlo dos veces. Los registros vinculados muestran un 🔗. Un botón "🔄 Actualizar" trae los turnos y clientes desde la web.
- **💰 Finanzas** — Panel (KPIs y gráficos), Cargar (cortes/productos), Servicios, Gráficos, **Cierre de caja diario** (registro inmutable por día con historial y exportación a CSV listo para Excel), **Clientes** (nombre + teléfono guardados automáticamente al reservar, con botón de WhatsApp), Barberos y comisiones, Precios, Gastos y sueldos, Stock.

Configuración (nombre, logo, sesión, accesos, respaldo JSON) accesible desde el ícono ⚙ junto al perfil.

## Estado
Sistema con reservas online conectadas a un backend real (Supabase) y login real por mail para el personal — ya en condiciones de usarse con una barbería real, siempre que se hayan seguido los 5 pasos de "Backend" de arriba (en especial desactivar el alta pública de usuarios). El resto del sistema (servicios, ventas, gastos, cierres) sigue siendo 100% local por dispositivo por ahora — no se sincroniza entre celular y compu.

### Si el proyecto de Supabase ya venía de una versión de prueba (sin login)
Si este repo ya estaba conectado a un proyecto de Supabase con las políticas viejas (abiertas, `using (true)` para todo), los datos existentes no se pierden, pero hasta que corras la migración y desactives el alta pública de usuarios (pasos 2 y 4 de arriba), cualquiera con el link podía leer/escribir directo contra la base sin pasar por la app. Es importante hacer esos dos pasos antes de considerar el sistema "en producción" para un cliente real.
