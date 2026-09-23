import { NextResponse, type NextRequest } from "next/server";

import { createClient } from "@/lib/supabase/server";

const allowedNextPaths = new Set(["/", "/app", "/onboarding"]);

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const flowId = request.nextUrl.searchParams.get("sb_flow_id");
  const requestedNext = request.nextUrl.searchParams.get("next") ?? "/app";
  const next = allowedNextPaths.has(requestedNext) ? requestedNext : "/app";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(
      code,
      flowId ? { flowId } : undefined,
    );

    if (!error) {
      return NextResponse.redirect(new URL(next, request.url));
    }
  }

  return NextResponse.redirect(
    new URL("/auth/login?error=auth_callback", request.url),
  );
}
