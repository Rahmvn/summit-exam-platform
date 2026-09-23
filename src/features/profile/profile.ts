import type { SupabaseClient } from "@supabase/supabase-js";

export type AcademicProfile = {
  user_id: string;
  full_name: string | null;
  matric_number: string | null;
  department_id: string | null;
  level_id: string | null;
  current_semester_id: string | null;
};

export function isProfileComplete(
  profile: AcademicProfile | null,
): profile is AcademicProfile & {
  full_name: string;
  matric_number: string;
  department_id: string;
  level_id: string;
  current_semester_id: string;
} {
  return Boolean(
    profile?.full_name?.trim() &&
      profile.matric_number?.trim() &&
      profile.department_id &&
      profile.level_id &&
      profile.current_semester_id,
  );
}

export async function getProfile(
  supabase: SupabaseClient,
  userId: string,
) {
  const { data, error } = await supabase
    .from("profiles")
    .select(
      "user_id, full_name, matric_number, department_id, level_id, current_semester_id",
    )
    .eq("user_id", userId)
    .maybeSingle();

  return {
    profile: (data as AcademicProfile | null) ?? null,
    error,
  };
}
