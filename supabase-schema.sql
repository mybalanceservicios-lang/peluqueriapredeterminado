-- Esquema para reservas online (turnos + configuración pública del negocio)
-- Ejecutar esto en: Supabase Dashboard -> SQL Editor -> New query -> pegar todo -> Run

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

alter table config enable row level security;
alter table turnos enable row level security;

-- Fase de prueba (sin login real todavía): lectura y escritura abiertas con la clave pública.
-- OJO: antes de compartir el link con clientes/barberías reales, hay que sumar un login real
-- para el dueño y restringir estas políticas (dejar público solo lo necesario: leer config,
-- leer turnos para calcular horarios libres, e insertar turnos nuevos).
create policy "config select publico" on config for select using (true);
create policy "config update publico" on config for update using (true);

create policy "turnos select publico" on turnos for select using (true);
create policy "turnos insert publico" on turnos for insert with check (true);
create policy "turnos update publico" on turnos for update using (true);
create policy "turnos delete publico" on turnos for delete using (true);
