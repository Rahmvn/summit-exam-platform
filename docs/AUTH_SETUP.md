# Authentication Setup

The application implements email/password authentication with Supabase Auth.
No provider secrets belong in this repository.

## Current acceptance state

Email/password authentication and academic onboarding have been tested
successfully against hosted Supabase. Google OAuth is intentionally deferred and
is not exposed by the V1 application.

## Hosted Supabase configuration

In the hosted Supabase project:

1. Keep email/password signups enabled and choose whether email confirmation is
   required for the development project.
2. Under **Authentication -> URL Configuration**, set the deployed application
   URL as the Site URL.
3. Add each application callback URL to the redirect allow list:

```text
http://localhost:3000/auth/callback
https://YOUR_APPLICATION_DOMAIN/auth/callback
```

The application uses the existing public environment variables only:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

Do not add service-role keys, database passwords, OAuth provider secrets or
other privileged credentials to browser environment variables or committed
files.

## Onboarding catalogue prerequisite

Academic onboarding requires active rows for Colleges, Departments, Levels,
Academic Sessions and Semesters in the hosted development database. The form
loads these records from Supabase and intentionally does not hardcode fallback
choices. If any required catalogue group is empty, students see a temporary
catalogue-not-ready state instead of an incomplete form.

`supabase/seed.sql` contains development/test catalogue data for onboarding
acceptance. It must not be treated as production academic data.
