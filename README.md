# Plantilla predeterminada — Gestión de Barbería

Sistema de gestión para barberías en un solo archivo HTML (sin backend, sin instalación). Sirve como base para ofrecer a barberías clientas: se clona/copia y se personaliza (nombre, logo, precios, barberos) por cliente.

## Cómo probarla
Abrí `index.html` en el navegador. Los datos se guardan en `localStorage` del navegador (no hay servidor).

## Qué incluye
- Selector de perfil por barbero + modo Dueño con PIN
- Carga rápida de cortes/servicios y venta de productos, con comisión automática por barbero
- Agenda de turnos con detección de choques de horario
- Panel con KPIs, gráficos de facturación y alertas de stock bajo mínimo
- **Cierre de caja diario**: registro inmutable por día (facturación, comisiones, gastos, neto por medio de pago), con historial y exportación a CSV (separador `;`, listo para Excel)
- Precios y comisiones editables (no afectan lo ya cargado)
- Respaldo/restauración manual en JSON

## Estado
Plantilla de demo/venta. Todavía corre 100% local (`localStorage`) — antes de entregarle el link a un cliente real, conviene migrarla a un backend con sincronización en la nube (mismo patrón que se usó en Malby Productos con Supabase) para soportar múltiples dispositivos sin perder datos.
