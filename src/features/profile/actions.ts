"use server";

import { redirect } from "next/navigation";

import { getVerifiedIdentity } from "@/features/auth/server";
import type { OnboardingActionState } from "@/features/profile/action-state";
import { getProfile } from "@/features/profile/profile";
import { createClient } from "@/lib/supabase/server";

function readRequired(formData: FormData, field: string) {
  return String(formData.get(field) ?? "").trim();
}

export async function saveOnboardingAction(
  _previousState: OnboardingActionState,
  formData: FormData,
): Promise<OnboardingActionState> {
  const supabase = await createClient();
  const identity = await getVerifiedIdentity(supabase);

  if (!identity) {
    redirect("/auth/login?error=expired");
  }

  const fullName = readRequired(formData, "full_name");
  const matricNumber = readRequired(formData, "matric_number");
  const collegeId = readRequired(formData, "college_id");
  const departmentId = readRequired(formData, "department_id");
  const levelId = readRequired(formData, "level_id");
  const academicSessionId = readRequired(formData, "academic_session_id");
  const currentSemesterId = readRequired(formData, "current_semester_id");

  if (
    !fullName ||
    !matricNumber ||
    !collegeId ||
    !departmentId ||
    !levelId ||
    !academicSessionId ||
    !currentSemesterId
  ) {
    return {
      status: "error",
      message: "Complete every field before continuing.",
    };
  }

  const [college, department, level, academicSession, semester] =
    await Promise.all([
      supabase
        .from("colleges")
        .select("id")
        .eq("id", collegeId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("departments")
        .select("id")
        .eq("id", departmentId)
        .eq("college_id", collegeId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("levels")
        .select("id")
        .eq("id", levelId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("academic_sessions")
        .select("id")
        .eq("id", academicSessionId)
        .eq("is_active", true)
        .maybeSingle(),
      supabase
        .from("semesters")
        .select("id")
        .eq("id", currentSemesterId)
        .eq("academic_session_id", academicSessionId)
        .eq("is_active", true)
        .maybeSingle(),
    ]);

  const catalogueQueries = [
    college,
    department,
    level,
    academicSession,
    semester,
  ];

  if (catalogueQueries.some((result) => result.error)) {
    return {
      status: "error",
      message: "We could not verify your academic selections. Please try again.",
    };
  }

  if (catalogueQueries.some((result) => !result.data)) {
    return {
      status: "error",
      message: "One of your academic selections is no longer available.",
    };
  }

  const profileValues = {
    full_name: fullName,
    matric_number: matricNumber,
    department_id: departmentId,
    level_id: levelId,
    current_semester_id: currentSemesterId,
  };
  const existingProfile = await getProfile(supabase, identity.userId);

  if (existingProfile.error) {
    return {
      status: "error",
      message: "We could not check your profile. Please try again.",
    };
  }

  const result = existingProfile.profile
    ? await supabase
        .from("profiles")
        .update(profileValues)
        .eq("user_id", identity.userId)
    : await supabase.from("profiles").insert({
        user_id: identity.userId,
        ...profileValues,
      });

  if (result.error) {
    return {
      status: "error",
      message:
        result.error.code === "23505"
          ? "That matric number is already connected to another account."
          : "We could not save your profile. Please try again.",
    };
  }

  redirect("/app");
}
