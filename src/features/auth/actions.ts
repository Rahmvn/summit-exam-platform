"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";

import type { AuthActionState } from "@/features/auth/action-state";
import { getVerifiedIdentity } from "@/features/auth/server";
import { createClient } from "@/lib/supabase/server";

function readCredentials(formData: FormData) {
  return {
    email: String(formData.get("email") ?? "")
      .trim()
      .toLowerCase(),
    password: String(formData.get("password") ?? ""),
  };
}

async function getRequestOrigin() {
  const requestHeaders = await headers();
  const originHeader = requestHeaders.get("origin");
  const requestHost = (
    requestHeaders.get("x-forwarded-host") ?? requestHeaders.get("host")
  )
    ?.split(",", 1)[0]
    .trim();

  if (!originHeader || !requestHost) {
    throw new Error("The application origin could not be determined.");
  }

  const origin = new URL(originHeader);

  if (
    !["http:", "https:"].includes(origin.protocol) ||
    origin.host !== requestHost
  ) {
    throw new Error("The application origin is not trusted.");
  }

  return origin.origin;
}

export async function signInAction(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const { email, password } = readCredentials(formData);

  if (!email || !password) {
    return {
      status: "error",
      message: "Enter your email address and password.",
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    return {
      status: "error",
      message:
        error.code === "invalid_credentials"
          ? "The email address or password is incorrect."
          : "We could not sign you in. Please try again.",
    };
  }

  redirect("/app");
}

export async function signUpAction(
  _previousState: AuthActionState,
  formData: FormData,
): Promise<AuthActionState> {
  const { email, password } = readCredentials(formData);

  if (!email || !password) {
    return {
      status: "error",
      message: "Enter an email address and password.",
    };
  }

  if (password.length < 6) {
    return {
      status: "error",
      message: "Use a password with at least 6 characters.",
    };
  }

  let origin: string;

  try {
    origin = await getRequestOrigin();
  } catch {
    return {
      status: "error",
      message: "We could not create your account. Please try again.",
    };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: `${origin}/auth/callback?next=/app`,
      },
  });

  if (error) {
    return {
      status: "error",
      message: "We could not create your account. Please try again.",
    };
  }

  if (data.session) {
    redirect("/app");
  }

  return {
    status: "success",
    message:
      "Account created. Check your email to confirm your address, then sign in.",
  };
}

export async function signOutAction() {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (identity) {
    await supabase.auth.signOut();
  }

  redirect("/auth/login");
}
