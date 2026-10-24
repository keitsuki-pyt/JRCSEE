-- Run after supabase-setup.sql to enable daily webcam face-track counts.
create table if not exists public.face_scan_events (
    id uuid primary key default gen_random_uuid(),
    scanner_id uuid references auth.users (id) on delete set null,
    occurred_at timestamptz not null default now()
);

create index if not exists face_scan_events_occurred_at_idx
    on public.face_scan_events (occurred_at desc);

alter table public.face_scan_events enable row level security;

drop policy if exists "Admin and personnel can read face scan events" on public.face_scan_events;
create policy "Admin and personnel can read face scan events"
on public.face_scan_events for select to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'personnel'
    )
);

drop policy if exists "Admin and personnel can record face scan events" on public.face_scan_events;
create policy "Admin and personnel can record face scan events"
on public.face_scan_events for insert to authenticated
with check (
    scanner_id = auth.uid()
    and (
        public.is_admin()
        or exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

revoke all on public.face_scan_events from anon, authenticated;
grant select, insert on public.face_scan_events to authenticated;

do $$
begin
    if exists (
        select 1 from pg_publication where pubname = 'supabase_realtime'
    ) and not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'face_scan_events'
    ) then
        alter publication supabase_realtime add table public.face_scan_events;
    end if;
end;
$$;

notify pgrst, 'reload schema';
