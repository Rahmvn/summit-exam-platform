import Link from "next/link";
import { redirect } from "next/navigation";

import { Button } from "@/components/ui/button";
import { getVerifiedIdentity } from "@/features/auth/server";
import { createClient } from "@/lib/supabase/server";

export default async function HomePage() {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (identity) {
    redirect("/app");
  }

  return (
    <section className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-5xl items-center px-6 py-16">
      <div className="max-w-2xl space-y-4">
        <p className="text-sm font-medium text-primary">Project foundation</p>
        <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
          Summit Exam Platform
        </h1>
        <p className="max-w-xl text-base leading-7 text-muted-foreground sm:text-lg">
          Sign in, complete your Summit academic profile and prepare for the
          student experience.
        </p>
        <div className="flex flex-wrap gap-3 pt-3">
          <Button asChild>
            <Link href="/auth/signup">Create account</Link>
          </Button>
          <Button asChild variant="outline">
            <Link href="/auth/login">Sign in</Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
