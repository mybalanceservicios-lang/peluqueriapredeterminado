# Plantilla predeterminada — Gestión de Barbería

Sistema de gestión para barberías: `index.html` (privado, para el dueño y barberos) + `reservar.html` (público, para que un cliente reserve turno). Sirve como base para ofrecer a barberías clientas: se clona/copia y se personaliza (nombre, logo, precios, barberos) por cliente.

## Cómo probarla
Abrí `index.html` en el navegador para el sistema de gestión, y `reservar.html` para la página de reservas. Turnos y configuración del negocio (horario, servicios visibles, barberos) se sincronizan con Supabase — ver "Backend" abajo. El resto de los datos (servicios cargados, ventas, gastos, cierres) todavía vive solo en `localStorage` de ese dispositivo.

## Backend (Supabase)
`supabase-schema.sql` tiene el SQL para crear las tablas `config` (una fila con los datos del negocio) y `turnos`. Hay que:
1. Crear un proyecto en [supabase.com](https://supabase.com).
2. Pegar y ejecutar `supabase-schema.sql` en el SQL Editor del proyecto.
3. Reemplazar `SUPABASE_URL` y `SUPABASE_ANON_KEY` (la "publishable key", nunca la "secret key") al principio del script de `index.html` y de `reservar.html`.

**Importante:** las políticas RLS de este esquema son abiertas (`using (true)`) — pensadas para probar, no para producción. Antes de compartir el link con una barbería real, hay que sumar un login real para el dueño y restringir esas políticas (dejar público solo lo necesario: leer `config`, leer `turnos` para calcular horarios libres, e insertar turnos nuevos).

## Qué incluye
Para el dueño, la navegación está organizada en 3 secciones:

- **🌐 Web virtual** — configuración de horario de atención, qué servicios mostrar, vista previa de la vidriera online, y texto listo para compartir por WhatsApp/Instagram. Desde acá hay un link a `reservar.html`, que ya funciona de verdad entre dispositivos distintos (un turno reservado desde un celular aparece en la Agenda de otra compu).
- **🗓 Agenda** — turnos con detección de choques de horario. Al marcar un turno como "Atendido" (eligiendo el medio de pago), se genera automáticamente el corte correspondiente en Finanzas — no hace falta cargarlo dos veces. Los registros vinculados muestran un 🔗. Un botón "🔄 Actualizar" trae los turnos reservados desde la web.
- **💰 Finanzas** — Panel (KPIs y gráficos), Cargar (cortes/productos), Servicios, Gráficos, **Cierre de caja diario** (registro inmutable por día con historial y exportación a CSV listo para Excel), Barberos y comisiones, Precios, Gastos y sueldos, Stock.

Selector de perfil por barbero + modo Dueño con PIN. Configuración (nombre, logo, clave, respaldo JSON) accesible desde el ícono ⚙ junto al perfil.

## Estado
Plantilla de demo/venta con reservas online ya conectadas a un backend real (Supabase), en modo de prueba. Antes de ofrecerlo a una barbería real: sumar un login real para el dueño (hoy es solo un PIN local, sin validar contra el backend) y cerrar las políticas RLS a lo mínimo necesario. El resto del sistema (servicios, ventas, gastos, cierres) sigue siendo 100% local por ahora.

