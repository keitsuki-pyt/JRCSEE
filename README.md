# JRCSEE — Face Recognition Web

JRCSEE is a web-based interface for an administrative dashboard. It supports Supabase email/password and Google sign-in, Supabase-backed profiles and dashboard records, and separate Admin and Personnel access.

> **Setup required:** Run [`supabase-setup.sql`](./supabase-setup.sql) in the Supabase SQL Editor and configure Google OAuth in Supabase before using database-backed features and Google sign-in. The database starts empty. A complete face-recognition workflow is not implemented in the supplied files.

## Features

- **Supabase Authentication** using email/password or Google
- **Role-based access** for Admin and Personnel, enforced by Supabase RLS
- **Account editor** for changing a profile display name and email
- **Password visibility toggle**
- **Remember me** checkbox in the login interface
- **Dashboard overview** with student statistics and report activity
- **Student, faculty, and visitor records** managed by Admin and Personnel; both roles can add and edit people records, while deletion is Admin-only
- **Reports and entry logs** managed by Admin
- **Members navigation** groups Students, Faculty, and Visitors in one expandable sidebar section
- **Dashboard color themes** with palette presets that update the dashboard accents and surfaces together
- **Visitor retention** with automatic deletion after 30 days and anonymized linked logs/alerts
- **Search** for filtering the information shown on each page
- **Responsive layout** with a collapsible sidebar on smaller screens
- **Live date and time display**
- **Dark purple visual theme** with animated effects on the login page

## Built With

- HTML5
- CSS3
- JavaScript
- [Supabase JavaScript Client](https://supabase.com/docs/reference/javascript/introduction)
- Google Fonts: Barlow Condensed, Poppins, Inter, and DM Mono

## Project Files

Example file structure:

```text
JRCSEE/
├── index.html       # Login page
├── google-role.html # Google account approval status
├── dashboard.html   # Dashboard page
├── JRCC.png         # JRCC logo used by the pages
├── supabase-setup.sql # Database tables, roles, and access policies
└── README.md
```

Make sure the filenames match the paths used in your HTML. The pages reference `JRCC.png`; email/password sign-ins continue to `dashboard.html`, while Google sign-ins go through `google-role.html` for an approval check.

## Getting Started

### Requirements

- A modern web browser
- A local web server or static hosting
- A Supabase project configured for email/password authentication

### 1. Download or clone the repository

```bash
git clone <your-repository-url>
cd JRCSEE
```

If you downloaded the files as a ZIP, extract them into one folder instead.

### 2. Configure Supabase

The HTML files use the Supabase JavaScript client and call `supabase.auth.signInWithPassword()` to sign in users.

1. Open the JRCSEE project in [Supabase](https://supabase.com/).
2. In **SQL Editor**, run [`supabase-setup.sql`](./supabase-setup.sql). It creates the people, entry-log, alert, and account tables/views, applies row-level security, and schedules expired visitor cleanup through `pg_cron`. The script is designed to be rerun; when upgrading an existing setup it keeps the old `members`, `projects`, and `reports` tables, but old member rows are not automatically converted into student/staff records.
   - For an existing project where the tables already exist, run [`supabase-people-fix.sql`](./supabase-people-fix.sql) to refresh people-table and category-view permissions without changing account roles. It assumes the setup script has already created the tables, views, and `is_admin()` function.
   - To remove the visitor host requirements from an existing database, run [`supabase-visitor-fields-fix.sql`](./supabase-visitor-fields-fix.sql) after the setup script. Existing host values are preserved but the updated form no longer collects or displays them.
   - To enable Recent Activity entries for student, faculty, and visitor additions, edits, and deletions in an existing database, run [`supabase-activity-fix.sql`](./supabase-activity-fix.sql).
3. In **Authentication → Providers**, enable Email and, if desired, Google.
4. In **Authentication → URL Configuration**, set the site's URL and add the app's `google-role.html` and `dashboard.html` URLs used during local development and deployment to the allowed redirect URLs.
5. Keep the Supabase project URL and **publishable** key in the HTML files in sync with your project. Never put a `service_role` key in browser code.

#### Enable Google sign-in

The login page includes a Google sign-in button. To enable it:

1. Create a Google OAuth web client in Google Cloud Console.
2. In Supabase, open **Authentication → Providers → Google**, enable Google, and enter the client ID and client secret there.
3. Add the Supabase callback URL shown on that provider settings page to the Google OAuth client's authorized redirect URIs.
4. In Supabase **URL Configuration**, add the app's local and production dashboard URLs to the redirect allow list.

OAuth secrets belong in Supabase's provider settings only; do not paste them into the HTML files or commit them.

#### Assign Admin and Personnel roles

New accounts start with the `pending` role and cannot access the dashboard until an administrator approves them. Google users see an approval-pending message after sign-in. To review pending accounts, run this in the Supabase SQL Editor:

```sql
select user_account.email, profile.full_name, profile.role, profile.created_at
from public.profiles as profile
join auth.users as user_account on user_account.id = profile.id
where profile.role = 'pending'
order by profile.created_at;
```

To approve an account, replace the email and role below with the account's email and either `personnel` or `admin`:

```sql
update public.profiles as profile
set role = 'personnel',
    role_assigned_by_admin = true,
    role_self_selected = false
from auth.users as user_account
where profile.id = user_account.id
  and lower(user_account.email) = lower('person@example.com');
```

Use `role = 'admin'` to approve an administrator. Approved users should sign out and sign in again to enter the dashboard. Run the current [`supabase-setup.sql`](./supabase-setup.sql) in the Supabase SQL Editor to enable this approval workflow. Applying it moves existing Personnel roles that were not assigned by an administrator back to `pending`, so review and approve those users again as needed. Existing Admin accounts remain assigned. On a fresh setup, approve the first Admin manually using the SQL above before using the Admin dashboard. Keep at least one Admin account. Do not make an account an Admin by changing only a staff record: `people.staff_role` is a staff member's position/title and is separate from the login role in `profiles.role`.

Admins have full read/write access to operational data tables under Supabase RLS. The dashboard supports adding, editing, and deleting people and reports, and reviewing or deleting entry logs. Personnel can view, add, and edit student, faculty, and visitor records; only Admin can delete people records. Projects and alerts remain in the database setup but are not currently shown in the dashboard. Entry logs are intended to be generated by a trusted access-control device/service rather than edited manually. Assigning login roles is separate and is done through the Supabase SQL Editor.

#### People and visitor retention

- Student records contain full name, course, year level, and email. Students are grouped by course alphabetically in the dashboard; course values remain editable. No student ID is required.
- Recent Activity includes report submissions and people-record additions, edits, and deletions.
- Staff records contain full name, email, job role/title, and department.
- Visitor records contain full name, purpose, and contact phone. Host name and host department are no longer collected. The database sets the 30-day expiration timestamp on registration.
- Expired visitor records are deleted by an hourly `pg_cron` job. The linked `person_id` in entry logs and alerts is set to `NULL` on deletion, leaving those records anonymized.
- The `students`, `staff`, and `visitors` views are filtered views over `people`; authenticated users can read, insert, and update through them subject to the same row-level security policies. The dashboard writes through `people` with an explicit person type.
- If a dashboard save fails, read the message below the form. A row-level-security or permission error usually means the current account is not approved as Admin/Personnel or the latest policies from `supabase-setup.sql` have not been applied. Student records must be saved as `person_type = 'student'` in `public.people` (or inserted through the `public.students` view with its required fields); older records in `public.members` are not shown as students.
- Face photos, biometric templates, and face recognition are not included. Entry logs and alerts will remain empty until an authorized access-control device/service writes to them.

The dashboard database starts empty. The names and reports previously shown in the dashboard were sample data and are not copied into your project.

**Security:** Only use a Supabase publishable/anon key in browser-side code. Never place a Supabase `service_role` key or other secret key in HTML or JavaScript. For a public deployment, consider moving configuration into a suitable environment/build setup and applying appropriate access controls.

### 3. Run the project

Open the project folder in your editor and serve it with a local development server. For example, if you have the VS Code Live Server extension, right-click `index.html` and choose **Open with Live Server**.

You can also use any local static web server. Opening the file directly may work for basic styling, but using a local server is recommended for testing authentication and navigation.

### 4. Sign in

Use an account created and configured in your Supabase project. Sign in with an email/password account or, once configured, Google.

After successful authentication, the login page redirects to `dashboard.html`.

## Current Scope and Limitations

- The **Remember me** checkbox is present in the interface, but persistent-login behavior is not implemented by that checkbox.
- The account email update requires confirmation from the email inbox.
- The supplied dashboard checks whether a Supabase user is signed in and uses Supabase Row Level Security (RLS) to protect database operations.
- Although the project is labeled “Face Recognition Web,” the supplied files do not implement camera access, face detection, face matching, or face-based attendance/identity verification.

## Suggested Improvements

- Implement a face-recognition workflow if it is part of the intended project scope.
- Add role assignment to a dedicated account-management page.
- Validate access policies and redirect URLs before deployment.

## License

No license is specified yet. Add a `LICENSE` file if you intend to publish or distribute this project.

## Acknowledgment

Developed as a web interface project associated with Jesus Reigns Christian College (JRCC).
