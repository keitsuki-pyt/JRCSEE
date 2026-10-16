create table if not exists public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    full_name text not null default '',
    role text not null default 'pending' check (role in ('pending', 'admin', 'personnel')),
    created_at timestamptz not null default now()
);

alter table public.profiles
    alter column role set default 'pending',
    add column if not exists role_assigned_by_admin boolean not null default false,
    add column if not exists role_self_selected boolean not null default false;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
    add constraint profiles_role_check check (role in ('pending', 'admin', 'personnel'));

update public.profiles
set role_assigned_by_admin = true,
    role_self_selected = false
where role = 'admin' and not role_assigned_by_admin;

update public.profiles
set role = 'pending'
where role = 'personnel'
  and not role_assigned_by_admin
  and not role_self_selected;

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

create table if not exists public.people (
    id uuid primary key default gen_random_uuid(),
    person_type text not null check (person_type in ('student', 'staff', 'visitor')),
    full_name text not null,
    email text,
    course text,
    year_level text,
    staff_role text,
    department text,
    purpose text,
    contact_phone text,
    host_name text,
    host_department text,
    registered_at timestamptz,
    expires_at timestamptz,
    created_at timestamptz not null default now(),
    constraint people_type_fields_check check (
        (person_type = 'student'
            and length(btrim(full_name)) > 0
            and course is not null and length(btrim(course)) > 0
            and year_level is not null and length(btrim(year_level)) > 0
            and email is not null and length(btrim(email)) > 0
            and staff_role is null and department is null and purpose is null
            and contact_phone is null and host_name is null and host_department is null
            and registered_at is null and expires_at is null)
        or
        (person_type = 'staff'
            and length(btrim(full_name)) > 0
            and staff_role is not null and length(btrim(staff_role)) > 0
            and department is not null and length(btrim(department)) > 0
            and email is not null and length(btrim(email)) > 0
            and course is null and year_level is null and purpose is null
            and contact_phone is null and host_name is null and host_department is null
            and registered_at is null and expires_at is null)
        or
        (person_type = 'visitor'
            and length(btrim(full_name)) > 0
            and purpose is not null and length(btrim(purpose)) > 0
            and contact_phone is not null and length(btrim(contact_phone)) > 0
            and host_name is not null and length(btrim(host_name)) > 0
            and host_department is not null and length(btrim(host_department)) > 0
            and course is null and year_level is null and email is null and staff_role is null
            and department is null and registered_at is not null and expires_at is not null)
    )
);

create index if not exists people_type_name_idx on public.people (person_type, full_name);
create index if not exists people_visitor_expiry_idx on public.people (expires_at)
where person_type = 'visitor';

create table if not exists public.entry_logs (
    id uuid primary key default gen_random_uuid(),
    person_id uuid references public.people (id) on delete set null,
    person_type text not null check (person_type in ('student', 'staff', 'visitor')),
    occurred_at timestamptz not null default now(),
    entry_point text not null,
    status text not null default 'allowed'
        check (status in ('allowed', 'denied', 'manual_review')),
    created_at timestamptz not null default now()
);

create index if not exists entry_logs_occurred_at_idx on public.entry_logs (occurred_at desc);
create index if not exists entry_logs_person_id_idx on public.entry_logs (person_id);

create table if not exists public.alerts (
    id uuid primary key default gen_random_uuid(),
    entry_log_id uuid references public.entry_logs (id) on delete set null,
    person_id uuid references public.people (id) on delete set null,
    alert_type text not null,
    occurred_at timestamptz not null default now(),
    resolved boolean not null default false,
    created_at timestamptz not null default now()
);

create index if not exists alerts_occurred_at_idx on public.alerts (occurred_at desc);

create or replace view public.students
with (security_invoker = true)
as
select id, full_name, course, year_level, email, created_at
from public.people
where person_type = 'student'
with local check option;

create or replace view public.staff
with (security_invoker = true)
as
select id, full_name, staff_role as role, department, email, created_at
from public.people
where person_type = 'staff'
with local check option;

create or replace view public.visitors
with (security_invoker = true)
as
select id, full_name, purpose, contact_phone, host_name, host_department,
       registered_at, expires_at, created_at
from public.people
where person_type = 'visitor'
with local check option;

create or replace function public.set_person_registration_times()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.person_type = 'visitor' then
        if tg_op = 'INSERT' then
            new.registered_at := statement_timestamp();
            new.expires_at := new.registered_at + interval '30 days';
        elsif old.person_type <> 'visitor' then
            new.registered_at := statement_timestamp();
            new.expires_at := new.registered_at + interval '30 days';
        end if;
    else
        new.registered_at := null;
        new.expires_at := null;
    end if;

    return new;
end;
$$;

drop trigger if exists set_person_registration_times on public.people;
create trigger set_person_registration_times
before insert or update on public.people
for each row execute function public.set_person_registration_times();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, full_name, role, role_assigned_by_admin, role_self_selected)
    values (
        new.id,
        coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
        case
            when lower(new.email) = 'legendlindel15@gmail.com'
                and new.raw_app_meta_data ->> 'provider' = 'google'
                and new.email_confirmed_at is not null
                then 'admin'
            else 'pending'
        end,
        coalesce(
            lower(new.email) = 'legendlindel15@gmail.com'
            and new.raw_app_meta_data ->> 'provider' = 'google'
            and new.email_confirmed_at is not null,
            false
        ),
        false
    )
    on conflict (id) do update
    set full_name = coalesce(excluded.full_name, public.profiles.full_name),
        role = case
            when public.profiles.role_assigned_by_admin then public.profiles.role
            when lower(excluded.id::text) is not null then public.profiles.role
            else public.profiles.role
        end,
        role_self_selected = public.profiles.role_self_selected;
    return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.profiles (id, full_name, role, role_assigned_by_admin, role_self_selected)
select
    id,
    coalesce(raw_user_meta_data ->> 'full_name', raw_user_meta_data ->> 'name', ''),
    case
        when lower(email) = 'legendlindel15@gmail.com'
            and raw_app_meta_data ->> 'provider' = 'google'
            and email_confirmed_at is not null
            then 'admin'
        else 'pending'
    end,
    case
        when lower(email) = 'legendlindel15@gmail.com'
            and raw_app_meta_data ->> 'provider' = 'google'
            and email_confirmed_at is not null
            then true
        else false
    end,
    false
from auth.users
on conflict (id) do nothing;

update public.profiles as profile
set role = 'admin',
    role_assigned_by_admin = true,
    role_self_selected = false
from auth.users as user_account
where profile.id = user_account.id
  and lower(user_account.email) = 'legendlindel15@gmail.com'
  and user_account.raw_app_meta_data ->> 'provider' = 'google'
  and user_account.email_confirmed_at is not null;

create or replace function public.ensure_profile_for_user(user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, full_name, role, role_assigned_by_admin, role_self_selected)
    select
        user_id,
        coalesce((select raw_user_meta_data ->> 'full_name' from auth.users where id = user_id), ''),
        'pending',
        false,
        false
    on conflict (id) do nothing;
end;
$$;

create or replace function public.assign_google_role(requested_role text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
    current_user_id uuid := auth.uid();
    current_email text;
    current_provider text;
    email_is_confirmed boolean;
    current_role text;
    current_role_admin_assigned boolean;
begin
    if current_user_id is null then
        raise exception 'You must sign in with Google before choosing a role.';
    end if;

    if requested_role not in ('admin', 'personnel') then
        raise exception 'Choose either Admin or Personnel.';
    end if;

    perform public.ensure_profile_for_user(current_user_id);

    select lower(email), raw_app_meta_data ->> 'provider', email_confirmed_at is not null
    into current_email, current_provider, email_is_confirmed
    from auth.users
    where id = current_user_id;

    if current_provider is distinct from 'google' then
        raise exception 'Role selection during sign-in is only available for Google accounts.';
    end if;

    if not coalesce(email_is_confirmed, false) then
        raise exception 'Your Google account email must be verified before choosing a role.';
    end if;

    select role, role_assigned_by_admin
    into current_role, current_role_admin_assigned
    from public.profiles
    where id = current_user_id;

    if current_role is null then
        insert into public.profiles (id, full_name, role, role_assigned_by_admin, role_self_selected)
        values (current_user_id, '', 'pending', false, false)
        on conflict (id) do nothing;

        select role, role_assigned_by_admin
        into current_role, current_role_admin_assigned
        from public.profiles
        where id = current_user_id;
    end if;

    if current_role is null then
        raise exception 'Your account profile is missing. Ask an administrator to check Supabase setup.';
    end if;

    if requested_role = 'admin' then
        if current_email = 'legendlindel15@gmail.com' then
            update public.profiles
            set role = 'admin',
                role_assigned_by_admin = true,
                role_self_selected = false
            where id = current_user_id;

            return 'admin';
        end if;

        if current_role = 'admin' and current_role_admin_assigned then
            return 'admin';
        end if;

        raise exception 'Admin access is limited to an approved administrator account. Choose Personnel or ask an administrator for access.';
    end if;

    if current_email = 'legendlindel15@gmail.com' then
        update public.profiles
        set role = 'personnel',
            role_assigned_by_admin = false,
            role_self_selected = true
        where id = current_user_id;

        return 'personnel';
    end if;

    if current_role = 'pending' then
        update public.profiles
        set role = 'personnel',
            role_assigned_by_admin = false,
            role_self_selected = true
        where id = current_user_id
          and role = 'pending';

        return 'personnel';
    end if;

    return current_role;
end;
$$;

revoke all on function public.assign_google_role(text) from public, anon;
grant execute on function public.assign_google_role(text) to authenticated;

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
alter table public.people enable row level security;
alter table public.entry_logs enable row level security;
alter table public.alerts enable row level security;

drop policy if exists "Signed-in users can read profiles" on public.profiles;
drop policy if exists "Admins can read all profiles" on public.profiles;
create policy "Admins can read all profiles"
on public.profiles for select to authenticated
using (public.is_admin());

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
on public.profiles for select to authenticated
using (id = auth.uid());

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
on public.profiles for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;

drop policy if exists "Signed-in users can read members" on public.members;
drop policy if exists "Admins can read legacy members" on public.members;
create policy "Admins can read legacy members"
on public.members for select to authenticated
using (public.is_admin());

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
drop policy if exists "Admins can read reports" on public.reports;
create policy "Admins can read reports"
on public.reports for select to authenticated
using (public.is_admin());

drop policy if exists "Users can submit their own reports" on public.reports;
drop policy if exists "Admins can submit reports" on public.reports;
create policy "Admins can submit reports" on public.reports
for insert to authenticated
with check (public.is_admin() and submitted_by = auth.uid());

drop policy if exists "Personnel can submit reports" on public.reports;

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

drop policy if exists "Admin and personnel can read students and visitors" on public.people;
create policy "Admin and personnel can read students and visitors"
on public.people for select to authenticated
using (
    public.is_admin()
    or (
        person_type in ('student', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

drop policy if exists "Admin and personnel can add students and visitors" on public.people;
create policy "Admin and personnel can add students and visitors"
on public.people for insert to authenticated
with check (
    public.is_admin()
    or (
        person_type in ('student', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

drop policy if exists "Admins can update people" on public.people;
create policy "Admins can update people"
on public.people for update to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can delete people" on public.people;
create policy "Admins can delete people"
on public.people for delete to authenticated
using (public.is_admin());

drop policy if exists "Admins can read entry logs" on public.entry_logs;
create policy "Admins can read entry logs"
on public.entry_logs for select to authenticated
using (public.is_admin());

drop policy if exists "Admins can manage entry logs" on public.entry_logs;
create policy "Admins can manage entry logs"
on public.entry_logs for all to authenticated
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage alerts" on public.alerts;
create policy "Admins can manage alerts"
on public.alerts for all to authenticated
using (public.is_admin())
with check (public.is_admin());

revoke all on public.people, public.entry_logs, public.alerts from anon, authenticated;
grant select, insert, update, delete on public.people to authenticated;
grant select, insert, update, delete on public.entry_logs, public.alerts to authenticated;

revoke all on public.students, public.staff, public.visitors from anon, authenticated;
grant select on public.students, public.staff, public.visitors to authenticated;

create extension if not exists pg_cron;

do $$
begin
    if exists (select 1 from cron.job where jobname = 'delete-expired-jrcsee-visitors') then
        perform cron.unschedule('delete-expired-jrcsee-visitors');
    end if;

    perform cron.schedule(
        'delete-expired-jrcsee-visitors',
        '0 * * * *',
        $job$delete from public.people
              where person_type = 'visitor'
                and expires_at <= now();$job$
    );
end;
$$;

notify pgrst, 'reload schema';
