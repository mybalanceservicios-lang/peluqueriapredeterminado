-- Esquema para el sistema de gestión + reservas online
-- Ejecutar esto en: Supabase Dashboard -> SQL Editor -> New query -> pegar todo -> Run
--
-- IMPORTANTE si ya habías corrido una versión anterior de este archivo: no vuelvas a
-- correr todo de nuevo, porque "create policy"/"create table" chocan con lo que ya existe.
-- Usá el bloque de migración al final de este archivo, según de qué versión vengas.

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

-- Invitaciones: códigos de un solo uso que el dueño genera desde la app para darle
-- acceso a un barbero, sin que nadie tenga que entrar al panel de Supabase.
-- El "tipo" y "nombre" quedan fijados acá por el dueño al crear el código — quien lo
-- canjea NO puede elegir libremente ser "dueño", solo obtiene el rol que el código dice.
create table if not exists invitaciones (
  codigo text primary key,
  tipo text not null check (tipo in ('owner','barber')),
  nombre text,
  usado boolean not null default false,
  usado_por uuid references auth.users(id),
  creado_por uuid references auth.users(id),
  creado_en timestamptz default now(),
  usado_en timestamptz
);

-- Perfiles: qué es cada persona que inicia sesión (dueño, o qué barbero puntual).
-- Se crea solo canjeando un código de invitación (ver la función/trigger más abajo),
-- excepto el primerísimo dueño, que puede autoasignarse una sola vez cuando el
-- sistema todavía no tiene ningún dueño.
create table if not exists perfiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  tipo text not null check (tipo in ('owner','barber')),
  nombre text,
  codigo_invitacion text,
  creado_en timestamptz default now()
);

alter table config enable row level security;
alter table turnos enable row level security;
alter table clientes enable row level security;
alter table invitaciones enable row level security;
alter table perfiles enable row level security;

-- config: la web pública necesita leerla para mostrar horario/servicios/barberos;
-- solo alguien con perfil asignado (dueño o barbero real) puede modificarla.
create policy "config select publico" on config for select using (true);
create policy "config update con perfil" on config for update using (exists (select 1 from perfiles where id = auth.uid()));

-- turnos: la web pública necesita leer (calcular horarios libres) e insertar (reservar);
-- editar (marcar atendido) y borrar quedan solo para quien tiene perfil asignado.
create policy "turnos select publico" on turnos for select using (true);
create policy "turnos insert publico" on turnos for insert with check (true);
create policy "turnos update con perfil" on turnos for update using (exists (select 1 from perfiles where id = auth.uid()));
create policy "turnos delete con perfil" on turnos for delete using (exists (select 1 from perfiles where id = auth.uid()));

-- clientes: la web pública necesita poder insertar/actualizar al reservar (nombre+teléfono),
-- pero no hace falta que pueda leer la lista completa (son datos de contacto de gente real).
create policy "clientes select con perfil" on clientes for select using (exists (select 1 from perfiles where id = auth.uid()));
create policy "clientes insert publico" on clientes for insert with check (true);
create policy "clientes update publico" on clientes for update using (true);

-- perfiles: cualquiera logueado puede ver la lista (son solo mail+rol del personal, sin
-- datos sensibles). Insertar/borrar queda regulado por el trigger de abajo, no por estas
-- políticas simples de select/update.
create policy "perfiles select autenticado" on perfiles for select using (auth.role() = 'authenticated');
create policy "perfiles insert propio" on perfiles for insert with check (auth.uid() = id);
create policy "perfiles delete con perfil" on perfiles for delete using (exists (select 1 from perfiles p2 where p2.id = auth.uid()));

-- invitaciones: solo el dueño puede crear y ver invitaciones. Nadie puede editarlas o
-- borrarlas directo — el canje (marcar "usado") lo hace el trigger de abajo con permisos
-- elevados, no el usuario común, para que no se pueda "reusar" un código manipulando la fila.
create policy "invitaciones insert dueño" on invitaciones for insert
  with check (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));
create policy "invitaciones select dueño" on invitaciones for select
  using (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));

-- Función + trigger: valida y canjea el código de invitación al crear un perfil nuevo.
-- - Si es el primerísimo perfil del sistema (todavía no hay ningún dueño) y no se manda
--   código: se permite auto-asignarse "owner" (arranque inicial, una sola vez posible).
-- - Si se manda un código: tiene que existir y no estar usado; se marca usado en el mismo
--   movimiento, y el tipo/nombre del perfil se toman del código (no de lo que mande quien
--   se está registrando), para que nadie pueda "pedir" ser dueño con un código de barbero.
create or replace function validar_alta_perfil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ya_hay_dueno boolean;
  inv record;
begin
  select exists(select 1 from perfiles where tipo = 'owner') into ya_hay_dueno;

  if new.codigo_invitacion is null then
    if ya_hay_dueno then
      raise exception 'Necesitás un código de invitación del dueño para entrar.';
    end if;
    if new.tipo <> 'owner' then
      raise exception 'El primer acceso del sistema tiene que ser el dueño.';
    end if;
    return new;
  end if;

  select * into inv from invitaciones where codigo = new.codigo_invitacion and usado = false;
  if not found then
    raise exception 'Código de invitación inválido o ya usado.';
  end if;

  update invitaciones set usado = true, usado_por = new.id, usado_en = now()
    where codigo = new.codigo_invitacion;

  new.tipo := inv.tipo;
  new.nombre := inv.nombre;
  return new;
end;
$$;

drop trigger if exists trg_validar_alta_perfil on perfiles;
create trigger trg_validar_alta_perfil
  before insert on perfiles
  for each row execute function validar_alta_perfil();


-- ============================================================
-- MUY IMPORTANTE: en el dashboard de Supabase, Authentication -> Providers -> Email,
-- dejá ACTIVADO "Allow new users to sign up". Acá, a diferencia de un sistema típico,
-- eso es correcto: cualquiera puede crear una cuenta de acceso, pero sin un código de
-- invitación válido esa cuenta no puede hacer nada (no tiene perfil, y sin perfil las
-- políticas de arriba no le dan ningún permiso real sobre turnos/config/clientes).
-- ============================================================


-- ============================================================
-- MIGRACIÓN si ya habías corrido una versión anterior con login por mail pero SIN
-- invitaciones (perfiles con políticas "... autenticado" usando auth.role()):
-- ============================================================
-- alter table perfiles add column if not exists codigo_invitacion text;
--
-- create table if not exists invitaciones (
--   codigo text primary key,
--   tipo text not null check (tipo in ('owner','barber')),
--   nombre text,
--   usado boolean not null default false,
--   usado_por uuid references auth.users(id),
--   creado_por uuid references auth.users(id),
--   creado_en timestamptz default now(),
--   usado_en timestamptz
-- );
-- alter table invitaciones enable row level security;
-- create policy "invitaciones insert dueño" on invitaciones for insert
--   with check (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));
-- create policy "invitaciones select dueño" on invitaciones for select
--   using (exists (select 1 from perfiles where id = auth.uid() and tipo = 'owner'));
--
-- drop policy if exists "config update autenticado" on config;
-- create policy "config update con perfil" on config for update using (exists (select 1 from perfiles where id = auth.uid()));
-- drop policy if exists "turnos update autenticado" on turnos;
-- create policy "turnos update con perfil" on turnos for update using (exists (select 1 from perfiles where id = auth.uid()));
-- drop policy if exists "turnos delete autenticado" on turnos;
-- create policy "turnos delete con perfil" on turnos for delete using (exists (select 1 from perfiles where id = auth.uid()));
-- drop policy if exists "clientes select autenticado" on clientes;
-- create policy "clientes select con perfil" on clientes for select using (exists (select 1 from perfiles where id = auth.uid()));
-- drop policy if exists "perfiles update autenticado" on perfiles;
-- drop policy if exists "perfiles delete autenticado" on perfiles;
-- create policy "perfiles delete con perfil" on perfiles for delete using (exists (select 1 from perfiles p2 where p2.id = auth.uid()));
--
-- (pegar acá también la función + trigger validar_alta_perfil de arriba)
--
-- Y en Authentication -> Providers -> Email: volver a ACTIVAR "Allow new users to sign up"
-- (si lo habías desactivado siguiendo instrucciones de una versión anterior de este archivo).


-- ============================================================
-- MIGRACIÓN si venías de la versión "de prueba" original (políticas abiertas
-- "... publico" para todo, sin login ni tabla perfiles):
-- ============================================================
-- Corré primero el bloque de arriba completo (perfiles, invitaciones, función y trigger
-- no existen todavía en tu proyecto), y de paso reemplazá las políticas abiertas:
--
-- drop policy if exists "config update publico" on config;
-- drop policy if exists "turnos update publico" on turnos;
-- drop policy if exists "turnos delete publico" on turnos;
-- drop policy if exists "clientes select publico" on clientes;
-- (las nuevas versiones de esas políticas ya están definidas más arriba en este archivo)
