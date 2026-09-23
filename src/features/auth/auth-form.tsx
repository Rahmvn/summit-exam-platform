"use client";

import Link from "next/link";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import {
  initialAuthActionState,
  type AuthActionState,
} from "@/features/auth/action-state";
import { signInAction, signUpAction } from "@/features/auth/actions";
import { Button } from "@/components/ui/button";

type AuthFormProps = {
  mode: "login" | "signup";
  initialMessage?: string;
};

function SubmitButton({ label }: { label: string }) {
  const { pending } = useFormStatus();

  return (
    <Button className="w-full" disabled={pending} type="submit">
      {pending ? "Please wait..." : label}
    </Button>
  );
}

function StatusMessage({ state }: { state: AuthActionState }) {
  if (!state.message) {
    return null;
  }

  return (
    <p
      className={
        state.status === "success"
          ? "rounded-md bg-emerald-50 px-3 py-2 text-sm text-emerald-800"
          : "rounded-md bg-red-50 px-3 py-2 text-sm text-red-700"
      }
      role={state.status === "error" ? "alert" : "status"}
    >
      {state.message}
    </p>
  );
}

export function AuthForm({ mode, initialMessage = "" }: AuthFormProps) {
  const action = mode === "login" ? signInAction : signUpAction;
  const [state, formAction] = useActionState(action, {
    ...initialAuthActionState,
    status: initialMessage ? "error" : "idle",
    message: initialMessage,
  } satisfies AuthActionState);
  const isLogin = mode === "login";

  return (
    <div className="w-full max-w-md rounded-xl border bg-card p-6 shadow-sm sm:p-8">
      <div className="space-y-2">
        <p className="text-sm font-medium text-primary">Student account</p>
        <h1 className="text-2xl font-semibold tracking-tight">
          {isLogin ? "Sign in" : "Create your account"}
        </h1>
        <p className="text-sm leading-6 text-muted-foreground">
          {isLogin
            ? "Continue to your Summit academic profile."
            : "Create an account before completing academic onboarding."}
        </p>
      </div>

      <form action={formAction} className="mt-6 space-y-4">
        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="email">
            Email address
          </label>
          <input
            autoComplete="email"
            className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            id="email"
            name="email"
            required
            type="email"
          />
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="password">
            Password
          </label>
          <input
            autoComplete={isLogin ? "current-password" : "new-password"}
            className="h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            id="password"
            minLength={6}
            name="password"
            required
            type="password"
          />
        </div>

        <StatusMessage state={state} />
        <SubmitButton label={isLogin ? "Sign in" : "Sign up"} />
      </form>

      <p className="mt-6 text-center text-sm text-muted-foreground">
        {isLogin ? "Need an account?" : "Already have an account?"}{" "}
        <Link
          className="font-medium text-primary hover:underline"
          href={isLogin ? "/auth/signup" : "/auth/login"}
        >
          {isLogin ? "Sign up" : "Sign in"}
        </Link>
      </p>
    </div>
  );
}
