import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@/components/ui/button";
import { loadOnboardingCatalogue } from "@/features/academics/onboarding-data";
import {
  getSuggestedFullName,
  getVerifiedIdentity,
} from "@/features/auth/server";
import { OnboardingForm } from "@/features/profile/onboarding-form";
import { getProfile, isProfileComplete } from "@/features/profile/profile";
import { createClient } from "@/lib/supabase/server";

export default async function OnboardingPage() {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (!identity) {
    redirect("/auth/login?error=expired");
  }

  const [{ profile, error: profileError }, catalogueResult] =
    await Promise.all([
      getProfile(supabase, identity.userId),
      loadOnboardingCatalogue(supabase),
    ]);

  if (profileError) {
    return (
      <section className="mx-auto max-w-2xl px-4 py-12 sm:px-6">
        <div className="rounded-xl border bg-card p-6 shadow-sm">
          <h1 className="text-xl font-semibold">Profile unavailable</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            We could not check your academic profile. Please try again in a
            moment.
          </p>
          <Button asChild className="mt-5" variant="outline">
            <Link href="/onboarding">Try again</Link>
          </Button>
        </div>
      </section>
    );
  }

  if (isProfileComplete(profile)) {
    redirect("/app");
  }

  if (catalogueResult.error || !catalogueResult.catalogue) {
    return (
      <section className="mx-auto max-w-2xl px-4 py-12 sm:px-6">
        <div className="rounded-xl border bg-card p-6 shadow-sm">
          <h1 className="text-xl font-semibold">Academic choices unavailable</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            We could not load the information needed for onboarding. Please try
            again in a moment.
          </p>
          <Button asChild className="mt-5" variant="outline">
            <Link href="/onboarding">Try again</Link>
          </Button>
        </div>
      </section>
    );
  }

  const catalogue = catalogueResult.catalogue;
  const catalogueIsReady =
    catalogue.colleges.length > 0 &&
    catalogue.departments.length > 0 &&
    catalogue.levels.length > 0 &&
    catalogue.sessions.length > 0 &&
    catalogue.semesters.length > 0;

  if (!catalogueIsReady) {
    return (
      <section className="mx-auto max-w-2xl px-4 py-12 sm:px-6">
        <div className="rounded-xl border bg-card p-6 shadow-sm">
          <h1 className="text-xl font-semibold">Academic choices not ready</h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            Onboarding is temporarily unavailable because the active academic
            catalogue has not been fully configured. Please try again later.
          </p>
          <Button asChild className="mt-5" variant="outline">
            <Link href="/onboarding">Try again</Link>
          </Button>
        </div>
      </section>
    );
  }

  return (
    <section className="mx-auto max-w-3xl px-4 py-10 sm:px-6 sm:py-14">
      <div className="rounded-xl border bg-card p-6 shadow-sm sm:p-8">
        <p className="text-sm font-medium text-primary">Academic onboarding</p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight">
          Tell us about your studies
        </h1>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-muted-foreground">
          Your profile helps us recommend relevant courses. It does not control
          which Course Offerings you can access.
        </p>

        <OnboardingForm
          catalogue={catalogue}
          profile={profile}
          suggestedFullName={getSuggestedFullName(identity.userMetadata)}
        />
      </div>
    </section>
  );
}
