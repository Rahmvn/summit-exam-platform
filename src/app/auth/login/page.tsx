import { redirect } from "next/navigation";

import { AuthForm } from "@/features/auth/auth-form";
import { getVerifiedIdentity } from "@/features/auth/server";
import { createClient } from "@/lib/supabase/server";

type LoginPageProps = {
  searchParams: Promise<{ error?: string }>;
};

const errorMessages: Record<string, string> = {
  expired: "Your sign-in has expired. Please sign in again.",
  auth_callback: "Your sign-in could not be completed. Please try again.",
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (identity) {
    redirect("/app");
  }

  const { error } = await searchParams;

  return (
    <section className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-5xl items-center justify-center px-4 py-12 sm:px-6">
      <AuthForm initialMessage={error ? errorMessages[error] : ""} mode="login" />
    </section>
  );
}
