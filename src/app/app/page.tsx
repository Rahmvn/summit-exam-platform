import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@/components/ui/button";
import { signOutAction } from "@/features/auth/actions";
import { getVerifiedIdentity } from "@/features/auth/server";
import { getProfile, isProfileComplete } from "@/features/profile/profile";
import { createClient } from "@/lib/supabase/server";

export default async function AuthenticatedLandingPage() {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (!identity) {
    redirect("/auth/login?error=expired");
  }

  const { profile, error } = await getProfile(supabase, identity.userId);

  if (error) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
        <div className="rounded-xl border bg-card p-6 shadow-sm">
          <h1 className="text-xl font-semibold">Profile unavailable</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            You are signed in, but we could not load your profile. Please try
            again.
          </p>
          <div className="mt-5 flex flex-wrap gap-3">
            <Button asChild variant="outline">
              <Link href="/app">Try again</Link>
            </Button>
            <form action={signOutAction}>
              <Button type="submit" variant="ghost">
                Sign out
              </Button>
            </form>
          </div>
        </div>
      </section>
    );
  }

  if (!isProfileComplete(profile)) {
    redirect("/onboarding");
  }

  return (
    <section className="mx-auto max-w-3xl px-4 py-12 sm:px-6">
      <div className="rounded-xl border bg-card p-6 shadow-sm sm:p-8">
        <p className="text-sm font-medium text-primary">Signed in</p>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight">
          Welcome, {profile.full_name}
        </h1>
        <p className="mt-3 max-w-xl text-sm leading-6 text-muted-foreground">
          Your academic onboarding is complete. The student dashboard will be
          built in a later milestone.
        </p>
        <dl className="mt-6 grid gap-4 rounded-lg bg-muted p-4 text-sm sm:grid-cols-2">
          <div>
            <dt className="text-muted-foreground">Matric number</dt>
            <dd className="mt-1 font-medium">{profile.matric_number}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">Account email</dt>
            <dd className="mt-1 font-medium">{identity.email ?? "Signed in"}</dd>
          </div>
        </dl>
        <form action={signOutAction} className="mt-6">
          <Button type="submit" variant="outline">
            Sign out
          </Button>
        </form>
      </div>
    </section>
  );
}
