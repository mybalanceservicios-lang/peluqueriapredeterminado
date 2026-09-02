# Plantilla predeterminada — Gestión de Barbería

Sistema de gestión para barberías en un solo archivo HTML (sin backend, sin instalación). Sirve como base para ofrecer a barberías clientas: se clona/copia y se personaliza (nombre, logo, precios, barberos) por cliente.

## Cómo probarla
Abrí `index.html` en el navegador. Los datos se guardan en `localStorage` del navegador (no hay servidor).

## Qué incluye
Para el dueño, la navegación está organizada en 3 secciones:

- **🌐 Web virtual** — configuración de horario de atención, qué servicios mostrar, vista previa de la vidriera online, y texto listo para compartir por WhatsApp/Instagram. Todavía es solo una vista previa (ver "Estado" abajo).
- **🗓 Agenda** — turnos con detección de choques de horario. Al marcar un turno como "Atendido" (eligiendo el medio de pago), se genera automáticamente el corte correspondiente en Finanzas — no hace falta cargarlo dos veces. Los registros vinculados muestran un 🔗.
- **💰 Finanzas** — Panel (KPIs y gráficos), Cargar (cortes/productos), Servicios, Gráficos, **Cierre de caja diario** (registro inmutable por día con historial y exportación a CSV listo para Excel), Barberos y comisiones, Precios, Gastos y sueldos, Stock.

Selector de perfil por barbero + modo Dueño con PIN. Configuración (nombre, logo, clave, respaldo JSON) accesible desde el ícono ⚙ junto al perfil.

## Estado
Plantilla de demo/venta. Todavía corre 100% local (`localStorage`) — la pestaña "Web virtual" es una vista previa, no un link público real. Para activar reservas online reales (que un cliente reserve desde su celular y aparezca en la Agenda) hace falta migrar a un backend con sincronización en la nube (mismo patrón que se usó en Malby Productos con Supabase), porque dos páginas/dispositivos distintos no pueden compartir `localStorage`.
