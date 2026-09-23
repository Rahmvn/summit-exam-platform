import type { SupabaseClient } from "@supabase/supabase-js";

export type VerifiedIdentity = {
  userId: string;
  email: string | null;
  userMetadata: Record<string, unknown>;
};

export async function getVerifiedIdentity(
  supabase: SupabaseClient,
): Promise<VerifiedIdentity | null> {
  const { data, error } = await supabase.auth.getClaims();

  if (error || !data?.claims.sub) {
    return null;
  }

  const metadata = data.claims.user_metadata;

  return {
    userId: data.claims.sub,
    email: typeof data.claims.email === "string" ? data.claims.email : null,
    userMetadata:
      metadata && typeof metadata === "object"
        ? (metadata as Record<string, unknown>)
        : {},
  };
}

export function getSuggestedFullName(metadata: Record<string, unknown>) {
  for (const key of ["full_name", "name"]) {
    const value = metadata[key];

    if (typeof value === "string" && value.trim()) {
      return value.trim();
    }
  }

  return "";
}
