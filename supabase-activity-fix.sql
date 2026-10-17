-- Run on an existing project to enable people-record Recent Activity entries.
create table if not exists public.activity_logs (
    id uuid primary key default gen_random_uuid(),
    actor_id uuid references public.profiles (id) on delete set null,
    actor_name text not null,
    action text not null check (action in ('added', 'updated', 'deleted')),
    person_type text not null check (person_type in ('student', 'staff', 'visitor')),
    person_name text not null,
    created_at timestamptz not null default now()
);

create index if not exists activity_logs_created_at_idx
    on public.activity_logs (created_at desc);

alter table public.activity_logs enable row level security;

drop policy if exists "Admin and personnel can read activity logs" on public.activity_logs;
create policy "Admin and personnel can read activity logs"
on public.activity_logs for select to authenticated
using (
    public.is_admin()
    or exists (
        select 1 from public.profiles
        where id = auth.uid() and role = 'personnel'
    )
);

drop policy if exists "Admin and personnel can record activity logs" on public.activity_logs;
create policy "Admin and personnel can record activity logs"
on public.activity_logs for insert to authenticated
with check (
    actor_id = auth.uid()
    and (
        public.is_admin()
        or exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

revoke all on public.activity_logs from anon, authenticated;
grant select, insert on public.activity_logs to authenticated;

notify pgrst, 'reload schema';
