import { redirect } from "next/navigation";

import { AuthForm } from "@/features/auth/auth-form";
import { getVerifiedIdentity } from "@/features/auth/server";
import { createClient } from "@/lib/supabase/server";

export default async function SignupPage() {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (identity) {
    redirect("/app");
  }

  return (
    <section className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-5xl items-center justify-center px-4 py-12 sm:px-6">
      <AuthForm mode="signup" />
    </section>
  );
}
