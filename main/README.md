# JRCSEE — Face Recognition Web

JRCSEE is a web-based interface for an administrative dashboard. It includes a login page with role selection for Admin and Personnel, along with a dashboard layout for viewing activity summaries, member statistics, project leads, and submitted reports.

> **Note:** The provided HTML files show a front-end prototype connected to Supabase Authentication. The dashboard's displayed member, project, and activity data is currently hard-coded sample data. A complete face-recognition workflow is not implemented in the supplied files.

## Features

- **Login interface** with Admin and Personnel role selection
- **Supabase Authentication** using email and password
- **Password visibility toggle**
- **Remember me** checkbox in the login interface
- **Dashboard overview** with member statistics and activity charts
- **Members view** listing project leads and their associated projects
- **Reports view** showing sample submitted reports
- **Search** for filtering the displayed member and report information
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

1. Create or open your project in [Supabase](https://supabase.com/).
2. Enable and configure the email/password sign-in method.
3. Review the Supabase project's authentication settings and allowed redirect URLs as needed.
4. Configure the project URL and publishable key in your application.

**Security:** Only use a Supabase publishable/anon key in browser-side code. Never place a Supabase `service_role` key or other secret key in HTML or JavaScript. For a public deployment, consider moving configuration into a suitable environment/build setup and applying appropriate access controls.

### 3. Run the project

Open the project folder in your editor and serve it with a local development server. For example, if you have the VS Code Live Server extension, right-click `index.html` and choose **Open with Live Server**.

You can also use any local static web server. Opening the file directly may work for basic styling, but using a local server is recommended for testing authentication and navigation.

### 4. Sign in

Use an account created and configured in your Supabase project. The login form expects an email address in the **Username** field and the account's password.

After successful authentication, the login page redirects to `dashboard.html`.

## Current Scope and Limitations

- The **Admin/Personnel selection is a visual role selector** in the supplied login code; it is not yet used to authorize or restrict accounts by role.
- The **Remember me** checkbox is present in the interface, but persistent-login behavior is not implemented by that checkbox.
- The **Forgot password?** text is displayed, but a password-reset action is not implemented.
- Dashboard charts, members, project leads, and reports use sample data embedded in JavaScript; they are not loaded from a database in the supplied code.
- The supplied dashboard checks whether a Supabase user is signed in and redirects unauthenticated visitors to `index.html`. For production, protect sensitive data and operations with server-side checks and Supabase Row Level Security (RLS), where applicable.
- Although the project is labeled “Face Recognition Web,” the supplied files do not implement camera access, face detection, face matching, or face-based attendance/identity verification.

## Suggested Improvements

- Implement role-based authorization for Admin and Personnel.
- Connect dashboard content to actual database tables.
- Add a working password-reset flow.
- Implement a face-recognition workflow if it is part of the intended project scope.
- Add loading states and user-friendly authentication feedback.
- Validate access policies and database permissions before deployment.

## License

No license is specified yet. Add a `LICENSE` file if you intend to publish or distribute this project.

## Acknowledgment

Developed as a web interface project associated with Jesus Reigns Christian College (JRCC).
