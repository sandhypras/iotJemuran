-- Smart Clothesline: skema awal. Jalankan di Supabase SQL Editor.
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Jemuran Rumah',
  pairing_code_hash text not null unique,
  device_secret_hash text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.app_device_access (
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid not null references public.devices(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, device_id)
);

create table if not exists public.device_status (
  device_id uuid primary key references public.devices(id) on delete cascade,
  mode text not null default 'automatic' check (mode in ('automatic', 'manual')),
  servo_position text not null default 'closed' check (servo_position in ('open', 'closed')),
  last_seen_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.sensor_readings (
  id bigint generated always as identity primary key,
  device_id uuid not null references public.devices(id) on delete cascade,
  rain_value integer not null check (rain_value >= 0),
  light_percent numeric(5,2) not null check (light_percent between 0 and 100),
  rain_detected boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists sensor_readings_device_time_idx on public.sensor_readings(device_id, created_at desc);

create table if not exists public.activity_history (
  id bigint generated always as identity primary key,
  device_id uuid not null references public.devices(id) on delete cascade,
  event_type text not null check (event_type in ('mode_changed', 'line_opened', 'line_closed')),
  message text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists activity_history_device_time_idx on public.activity_history(device_id, created_at desc);

create table if not exists public.device_commands (
  id uuid primary key default gen_random_uuid(),
  sequence_no bigint generated always as identity unique not null,
  device_id uuid not null references public.devices(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  command_type text not null check (command_type in ('set_mode', 'open', 'close')),
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'queued' check (status in ('queued', 'completed', 'failed')),
  result_message text,
  created_at timestamptz not null default now(),
  processed_at timestamptz
);
create index if not exists device_commands_queue_idx on public.device_commands(device_id, status, created_at);

create or replace function public.has_device_access(target_device_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_device_access a
    join public.devices d on d.id = a.device_id and d.enabled
    where a.device_id = target_device_id
      and a.user_id = (select auth.uid())
  );
$$;
revoke all on function public.has_device_access(uuid) from public, anon;
grant execute on function public.has_device_access(uuid) to authenticated;

alter table public.devices enable row level security;
alter table public.app_device_access enable row level security;
alter table public.device_status enable row level security;
alter table public.sensor_readings enable row level security;
alter table public.activity_history enable row level security;
alter table public.device_commands enable row level security;

drop policy if exists "users can read their own device links" on public.app_device_access;
create policy "users can read their own device links"
  on public.app_device_access for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "paired users can read device status" on public.device_status;
create policy "paired users can read device status"
  on public.device_status for select to authenticated
  using (public.has_device_access(device_id));

drop policy if exists "paired users can read sensor history" on public.sensor_readings;
create policy "paired users can read sensor history"
  on public.sensor_readings for select to authenticated
  using (public.has_device_access(device_id));

drop policy if exists "paired users can read activity history" on public.activity_history;
create policy "paired users can read activity history"
  on public.activity_history for select to authenticated
  using (public.has_device_access(device_id));

revoke all on public.devices, public.device_commands from anon, authenticated;
revoke all on public.app_device_access from anon, authenticated;
revoke all on public.device_status, public.sensor_readings, public.activity_history from anon, authenticated;
grant select on public.app_device_access, public.device_status, public.sensor_readings, public.activity_history to authenticated;
grant usage, select on sequence public.sensor_readings_id_seq, public.activity_history_id_seq, public.device_commands_sequence_no_seq to service_role;

-- Supabase Realtime: add the three read-only app tables once.
do $$
declare target_table text;
begin
  foreach target_table in array array['device_status', 'sensor_readings', 'activity_history'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = target_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', target_table);
    end if;
  end loop;
end $$;

-- Provision a device in SQL Editor. Replace both placeholders with random values
-- (pairing code: at least 12 random characters; device secret: 32+ random bytes).
-- Save the returned id and plaintext credentials directly into ESP8266 firmware.
-- Only SHA-256 hashes remain in this database.
--
-- insert into public.devices (name, pairing_code_hash, device_secret_hash)
-- values (
--   'Jemuran Rumah',
--   encode(extensions.digest('GANTI_KODE_PAIRING_ACAK', 'sha256'), 'hex'),
--   encode(extensions.digest('GANTI_SECRET_PERANGKAT_ACAK', 'sha256'), 'hex')
-- ) returning id;
