import type { SupabaseClient } from "@supabase/supabase-js";

export type CollegeOption = { id: string; name: string; code: string };
export type DepartmentOption = {
  id: string;
  college_id: string;
  name: string;
  code: string;
};
export type LevelOption = { id: string; code: string; label: string };
export type SessionOption = { id: string; label: string };
export type SemesterOption = {
  id: string;
  academic_session_id: string;
  name: string;
  semester_number: number;
};

export type OnboardingCatalogue = {
  colleges: CollegeOption[];
  departments: DepartmentOption[];
  levels: LevelOption[];
  sessions: SessionOption[];
  semesters: SemesterOption[];
};

export async function loadOnboardingCatalogue(
  supabase: SupabaseClient,
): Promise<{ catalogue: OnboardingCatalogue | null; error: boolean }> {
  const [colleges, departments, levels, sessions, semesters] =
    await Promise.all([
      supabase
        .from("colleges")
        .select("id, name, code")
        .eq("is_active", true)
        .order("name"),
      supabase
        .from("departments")
        .select("id, college_id, name, code")
        .eq("is_active", true)
        .order("name"),
      supabase
        .from("levels")
        .select("id, code, label")
        .eq("is_active", true)
        .order("sort_order"),
      supabase
        .from("academic_sessions")
        .select("id, label")
        .eq("is_active", true)
        .order("start_year", { ascending: false }),
      supabase
        .from("semesters")
        .select("id, academic_session_id, name, semester_number")
        .eq("is_active", true)
        .order("semester_number"),
    ]);

  if (
    colleges.error ||
    departments.error ||
    levels.error ||
    sessions.error ||
    semesters.error
  ) {
    return { catalogue: null, error: true };
  }

  return {
    catalogue: {
      colleges: (colleges.data ?? []) as CollegeOption[],
      departments: (departments.data ?? []) as DepartmentOption[],
      levels: (levels.data ?? []) as LevelOption[],
      sessions: (sessions.data ?? []) as SessionOption[],
      semesters: (semesters.data ?? []) as SemesterOption[],
    },
    error: false,
  };
}
