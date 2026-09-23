-- Esquema para el sistema de gestión + reservas online
-- Ejecutar esto en: Supabase Dashboard -> SQL Editor -> New query -> pegar todo -> Run
--
-- IMPORTANTE si ya habías corrido una versión anterior de este archivo (con políticas
-- "... publico" abiertas para todo): no vuelvas a correr este archivo completo, porque
-- "create policy" no se puede repetir sin borrar antes la policy vieja. Usá en cambio
-- el bloque de migración al final de este archivo ("MIGRACIÓN DESDE LA VERSIÓN ABIERTA").

-- Configuración del negocio: una sola fila ("default").
-- Es lo que lee la página de reservas (reservar.html) para mostrar horario, servicios y barberos.
create table if not exists config (
  id text primary key default 'default',
  nombre text default 'Mi Barbería',
  logo text,
  horario jsonb default '{"apertura":"09:00","cierre":"20:00","duracion":30,"dias":[1,2,3,4,5,6]}'::jsonb,
  precios jsonb default '[]'::jsonb,
  barberos jsonb default '[]'::jsonb,
  updated_at timestamptz default now()
);
insert into config (id) values ('default') on conflict (id) do nothing;

-- Turnos: agenda compartida entre el sistema de gestión y la página de reservas.
create table if not exists turnos (
  id text primary key,
  fecha date not null,
  hora text not null,
  barbero text not null,
  cliente text not null,
  telefono text,
  servicio text not null,
  estado text default 'pend',
  origen text default 'app',
  servicio_id text,
  created_at timestamptz default now()
);

-- Clientes: ficha simple (nombre + teléfono) para poder mandar recordatorios por WhatsApp.
-- Es una tabla aparte de turnos porque turnos sólo guarda los próximos (fecha >= hoy);
-- así los clientes quedan guardados aunque sus turnos pasados ya no aparezcan en la agenda.
create table if not exists clientes (
  telefono text primary key,
  nombre text not null,
  notas text,
  creado_en timestamptz default now(),
  actualizado_en timestamptz default now()
);

-- Perfiles: qué es cada persona que inicia sesión (dueño, o qué barbero puntual).
-- El dueño le crea el login a cada quien desde Authentication -> Users -> Add user en
-- este mismo panel de Supabase; la primera vez que esa persona entra a la app, elige
-- quién es y eso queda guardado acá para las próximas veces.
create table if not exists perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  tipo text not null check (tipo in ('owner','barber')),
  nombre text,
  creado_en timestamptz default now()
);

alter table config enable row level security;
alter table turnos enable row level security;
alter table clientes enable row level security;
alter table perfiles enable row level security;

-- config: la web pública necesita leerla para mostrar horario/servicios/barberos;
-- solo el personal logueado puede modificarla.
create policy "config select publico" on config for select using (true);
create policy "config update autenticado" on config for update using (auth.role() = 'authenticated');

-- turnos: la web pública necesita leer (calcular horarios libres) e insertar (reservar);
-- editar (marcar atendido) y borrar quedan solo para el personal logueado.
create policy "turnos select publico" on turnos for select using (true);
create policy "turnos insert publico" on turnos for insert with check (true);
create policy "turnos update autenticado" on turnos for update using (auth.role() = 'authenticated');
create policy "turnos delete autenticado" on turnos for delete using (auth.role() = 'authenticated');

-- clientes: la web pública necesita poder insertar/actualizar al reservar (nombre+teléfono),
-- pero no hace falta que pueda leer la lista completa (son datos de contacto de gente real).
create policy "clientes select autenticado" on clientes for select using (auth.role() = 'authenticated');
create policy "clientes insert publico" on clientes for insert with check (true);
create policy "clientes update publico" on clientes for update using (true);

-- perfiles: solo gente logueada puede ver/gestionar quién es quién (son solo mail+rol del personal).
create policy "perfiles select autenticado" on perfiles for select using (auth.role() = 'authenticated');
create policy "perfiles insert propio" on perfiles for insert with check (auth.uid() = id);
create policy "perfiles update autenticado" on perfiles for update using (auth.role() = 'authenticated');
create policy "perfiles delete autenticado" on perfiles for delete using (auth.role() = 'authenticated');


-- ============================================================
-- MIGRACIÓN DESDE LA VERSIÓN ABIERTA (correr esto si ya tenías las tablas
-- config/turnos/clientes creadas con las políticas viejas "... publico" para todo)
-- ============================================================
-- 1) Crear la tabla nueva de perfiles:
--
-- create table if not exists perfiles (
--   id uuid primary key references auth.users(id) on delete cascade,
--   email text,
--   tipo text not null check (tipo in ('owner','barber')),
--   nombre text,
--   creado_en timestamptz default now()
-- );
-- alter table perfiles enable row level security;
-- create policy "perfiles select autenticado" on perfiles for select using (auth.role() = 'authenticated');
-- create policy "perfiles insert propio" on perfiles for insert with check (auth.uid() = id);
-- create policy "perfiles update autenticado" on perfiles for update using (auth.role() = 'authenticated');
-- create policy "perfiles delete autenticado" on perfiles for delete using (auth.role() = 'authenticated');
--
-- 2) Reemplazar las políticas abiertas de config/turnos/clientes por las de arriba:
--
-- drop policy if exists "config update publico" on config;
-- create policy "config update autenticado" on config for update using (auth.role() = 'authenticated');
--
-- drop policy if exists "turnos update publico" on turnos;
-- create policy "turnos update autenticado" on turnos for update using (auth.role() = 'authenticated');
-- drop policy if exists "turnos delete publico" on turnos;
-- create policy "turnos delete autenticado" on turnos for delete using (auth.role() = 'authenticated');
--
-- drop policy if exists "clientes select publico" on clientes;
-- create policy "clientes select autenticado" on clientes for select using (auth.role() = 'authenticated');
--
-- 3) Muy importante: en el dashboard de Supabase ir a Authentication -> Providers -> Email
--    y desactivar "Allow new users to sign up" (o el equivalente en tu versión del panel).
--    Sin esto, cualquiera podría crear su propia cuenta llamando directo a la API de
--    Supabase, sin pasar por la app. Los únicos accesos válidos deben ser los que el
--    dueño cree a mano en Authentication -> Users -> Add user.
