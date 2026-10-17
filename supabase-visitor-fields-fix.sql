-- Run on an existing project to allow visitor records without host details.
alter table public.people drop constraint if exists people_type_fields_check;
alter table public.people
    add constraint people_type_fields_check check (
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
            and course is null and year_level is null and email is null and staff_role is null
            and department is null and registered_at is not null and expires_at is not null)
    );
