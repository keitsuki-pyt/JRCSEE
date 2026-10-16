# JRCSEE — Face Recognition Web

JRCSEE is a web-based interface for an administrative dashboard. It supports Supabase email/password and Google sign-in, Supabase-backed profiles and dashboard records, and separate Admin and Personnel access.

> **Setup required:** Run [`supabase-setup.sql`](./supabase-setup.sql) in the Supabase SQL Editor and configure Google OAuth in Supabase before using database-backed features and Google sign-in. The database starts empty. A complete face-recognition workflow is not implemented in the supplied files.

## Features

- **Supabase Authentication** using email/password or Google
- **Role-based access** for Admin and Personnel, enforced by Supabase RLS
- **Account editor** for changing a profile display name and email
- **Password visibility toggle**
- **Remember me** checkbox in the login interface
- **Dashboard overview** with member statistics and activity charts from Supabase records
- **Members and projects** stored in Supabase and manageable by Admins
- **Reports** stored in Supabase; Personnel can submit reports
- **Search** for filtering member, project, and report information
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
├── dashboard.html   # Dashboard page
├── JRCC.png         # JRCC logo used by the pages
├── supabase-setup.sql # Database tables, roles, and access policies
└── README.md
```

Make sure the filenames match the paths used in your HTML. The login page references `JRCC.png` and redirects successful sign-ins to `dashboard.html`.

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
2. In **SQL Editor**, run [`supabase-setup.sql`](./supabase-setup.sql) once. This creates the profile, member, project, and report tables, along with row-level security policies.
3. In **Authentication → Providers**, enable Email and, if desired, Google.
4. In **Authentication → URL Configuration**, set the site's URL and add the dashboard URL used during local development and deployment to the allowed redirect URLs.
5. Keep the Supabase project URL and **publishable** key in the two HTML files in sync with your project. Never put a `service_role` key in browser code.

#### Enable Google sign-in

The login page includes a Google sign-in button. To enable it:

1. Create a Google OAuth web client in Google Cloud Console.
2. In Supabase, open **Authentication → Providers → Google**, enable Google, and enter the client ID and client secret there.
3. Add the Supabase callback URL shown on that provider settings page to the Google OAuth client's authorized redirect URIs.
4. In Supabase **URL Configuration**, add the app's local and production dashboard URLs to the redirect allow list.

OAuth secrets belong in Supabase's provider settings only; do not paste them into the HTML files or commit them.

#### Assign Admin and Personnel roles

New accounts (including Google accounts) are assigned the **Personnel** role by default. The login page no longer lets users choose their own role. To promote an account to Admin, first have that person sign in, then run this in the Supabase SQL Editor, replacing the email:

```sql
update public.profiles
set role = 'admin'
where id = (
    select id
    from auth.users
    where email = 'admin@example.com'
);
```

Admins can add and delete members and projects, view the dashboard, and delete reports. Personnel can access Members and Reports and submit reports; project records and the overview are restricted to Admins. Row-level security enforces these permissions in Supabase, not just in the browser.

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
- Add editing for existing member, project, and report records.
- Validate access policies and redirect URLs before deployment.

## License

No license is specified yet. Add a `LICENSE` file if you intend to publish or distribute this project.

## Acknowledgment

Developed as a web interface project associated with Jesus Reigns Christian College (JRCC).
