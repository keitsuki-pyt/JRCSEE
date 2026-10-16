create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    full_name text not null default '',
    role text not null default 'personnel' check (role in ('admin', 'personnel')),
    created_at timestamptz not null default now()
);

create table if not exists public.members (
    id uuid primary key default gen_random_uuid(),
    full_name text not null,
    email text,
    department text,
    created_by uuid references auth.users (id) on delete set null,
    created_at timestamptz not null default now()
);

create table if not exists public.projects (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    category text not null default '',
    lead text not null default '',
    status text not null default 'Active',
    progress integer not null default 0 check (progress between 0 and 100),
    team_size integer not null default 0 check (team_size >= 0),
    due_date date,
    created_at timestamptz not null default now()
);

create table if not exists public.reports (
    id uuid primary key default gen_random_uuid(),
    title text not null,
    body text not null default '',
    submitted_by uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now()
);

create index if not exists reports_created_at_idx on public.reports (created_at desc);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, full_name, role)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
        'personnel'
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, role)
select
    id,
    coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', ''),
    'personnel'
from auth.users
on conflict (id) do nothing;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.profiles
        where id = auth.uid()
          and role = 'admin'
    );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

alter table public.profiles enable row level security;
alter table public.members enable row level security;
alter table public.projects enable row level security;
alter table public.reports enable row level security;

drop policy if exists "Signed-in users can read profiles" on public.profiles;
create policy "Signed-in users can read profiles"
on public.profiles for select to authenticated
using (auth.uid() is not null);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

drop policy if exists "Signed-in users can read members" on public.members;
create policy "Signed-in users can read members"
on public.members for select to authenticated
using (auth.uid() is not null);

drop policy if exists "Admins can insert members" on public.members;
create policy "Admins can insert members"
on public.members for insert to authenticated
with check (public.is_admin());

drop policy if exists "Admins can update members" on public.members;
create policy "Admins can update members"
on public.members for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete members" on public.members;
create policy "Admins can delete members"
on public.members for delete to authenticated
using (public.is_admin());

drop policy if exists "Signed-in users can read projects" on public.projects;
drop policy if exists "Admins can read projects" on public.projects;
create policy "Admins can read projects"
on public.projects for select to authenticated
using (public.is_admin());

drop policy if exists "Admins can insert projects" on public.projects;
create policy "Admins can insert projects"
on public.projects for insert to authenticated
with check (public.is_admin());

drop policy if exists "Admins can update projects" on public.projects;
create policy "Admins can update projects"
on public.projects for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete projects" on public.projects;
create policy "Admins can delete projects"
on public.projects for delete to authenticated
using (public.is_admin());

drop policy if exists "Signed-in users can read reports" on public.reports;
create policy "Signed-in users can read reports"
on public.reports for select to authenticated
using (auth.uid() is not null);

drop policy if exists "Users can submit their own reports" on public.reports;
create policy "Users can submit their own reports"
on public.reports for insert to authenticated
with check (submitted_by = auth.uid());

drop policy if exists "Admins can update reports" on public.reports;
create policy "Admins can update reports"
on public.reports for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete reports" on public.reports;
create policy "Admins can delete reports"
on public.reports for delete to authenticated
using (public.is_admin());

revoke all on public.members, public.projects, public.reports from anon, authenticated;
grant select, insert, update, delete on public.members, public.projects to authenticated;
grant select, insert, update, delete on public.reports to authenticated;
