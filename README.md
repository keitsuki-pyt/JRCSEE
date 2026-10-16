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
- **Student and visitor records** managed by Admin and Personnel; Personnel can view and add only these categories
- **Faculty, projects, reports, entry logs, and alerts** managed by Admin
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
├── google-role.html # Google sign-in role selection
├── dashboard.html   # Dashboard page
├── JRCC.png         # JRCC logo used by the pages
├── supabase-setup.sql # Database tables, roles, and access policies
└── README.md
```

Make sure the filenames match the paths used in your HTML. The pages reference `JRCC.png`; email/password sign-ins continue to `dashboard.html`, while Google sign-ins go through `google-role.html` first.

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

After Google verifies the account, [`google-role.html`](./google-role.html) lets the user choose Admin or Personnel. The selection is applied through the `assign_google_role` Supabase RPC; run the current [`supabase-setup.sql`](./supabase-setup.sql) in the Supabase SQL Editor to create that function. Google users may self-select Personnel. Only the confirmed Google account `legendlindel15@gmail.com` may self-assign Admin; other Admin access must already have been granted by an administrator. Existing verified Google accounts with that email are promoted by the setup script. Email/password accounts still require an administrator to assign their role. Supabase RLS remains the authority for every database operation.

To manually assign a role to another account after it has signed in once, run this in the Supabase SQL Editor and replace the email:

```sql
update public.profiles
set role = 'admin',
    role_assigned_by_admin = true
where id = (
    select id
    from auth.users
    where email = 'admin@example.com'
);
```

Use `role = 'personnel'` instead to grant Personnel access. The setup script marks existing Admin profiles as assigned and moves unapproved Personnel profiles to pending, so check and reassign existing accounts after applying the update. Keep at least one Admin account. Do not make an account an Admin by changing only a staff record: `people.staff_role` is a staff member's position/title and is separate from the login role in `profiles.role`.

Admins have full read/write access to operational data tables under Supabase RLS. The dashboard supports adding, editing, and deleting people, projects, and reports; resolving or deleting alerts; and reviewing or deleting entry logs. Entry logs are intended to be generated by a trusted access-control device/service rather than edited manually. Assigning login roles is separate and is done through the Supabase SQL Editor. Personnel can view and add student and visitor records only.

#### People and visitor retention

- Student records contain full name, course, year level, and email. No student ID is required.
- Staff records contain full name, email, job role/title, and department.
- Visitor records contain full name, purpose, contact phone, host name, and host department. The database sets the 30-day expiration timestamp on registration.
- Expired visitor records are deleted by an hourly `pg_cron` job. The linked `person_id` in entry logs and alerts is set to `NULL` on deletion, leaving those records anonymized.
- The `students`, `staff`, and `visitors` views are read-only filtered views over `people`. The dashboard writes through the `people` table with an explicit person type.
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
