-- Apply after supabase-setup.sql to repair people access without changing account roles.
grant usage on schema public to authenticated;
alter table public.people enable row level security;

revoke all on public.people from anon, authenticated;
grant select, insert, update, delete on public.people to authenticated;

revoke all on public.students, public.staff, public.visitors from anon, authenticated;
grant select, insert, update on public.students, public.staff, public.visitors to authenticated;

drop policy if exists "Admin and personnel can read students and visitors" on public.people;
drop policy if exists "Admin and personnel can read all people" on public.people;
create policy "Admin and personnel can read all people"
on public.people for select to authenticated
using (
    public.is_admin()
    or (
        person_type in ('student', 'staff', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

drop policy if exists "Admin and personnel can add students and visitors" on public.people;
drop policy if exists "Admin and personnel can add all people" on public.people;
create policy "Admin and personnel can add all people"
on public.people for insert to authenticated
with check (
    public.is_admin()
    or (
        person_type in ('student', 'staff', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

drop policy if exists "Admins can update people" on public.people;
drop policy if exists "Admin and personnel can update all people" on public.people;
create policy "Admin and personnel can update all people"
on public.people for update to authenticated
using (
    public.is_admin()
    or (
        person_type in ('student', 'staff', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
)
with check (
    public.is_admin()
    or (
        person_type in ('student', 'staff', 'visitor')
        and exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'personnel'
        )
    )
);

drop policy if exists "Admins can delete people" on public.people;
create policy "Admins can delete people"
on public.people for delete to authenticated
using (public.is_admin());

notify pgrst, 'reload schema';
