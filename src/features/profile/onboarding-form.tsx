"use client";

import { useMemo, useState } from "react";
import { useActionState } from "react";
import { useFormStatus } from "react-dom";

import { Button } from "@/components/ui/button";
import type { OnboardingCatalogue } from "@/features/academics/onboarding-data";
import { initialOnboardingActionState } from "@/features/profile/action-state";
import { saveOnboardingAction } from "@/features/profile/actions";
import type { AcademicProfile } from "@/features/profile/profile";

type OnboardingFormProps = {
  catalogue: OnboardingCatalogue;
  profile: AcademicProfile | null;
  suggestedFullName: string;
};

function SaveButton() {
  const { pending } = useFormStatus();

  return (
    <Button className="w-full sm:w-auto" disabled={pending} type="submit">
      {pending ? "Saving profile..." : "Complete onboarding"}
    </Button>
  );
}

const fieldClassName =
  "h-10 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:cursor-not-allowed disabled:opacity-50";

export function OnboardingForm({
  catalogue,
  profile,
  suggestedFullName,
}: OnboardingFormProps) {
  const initialDepartment = catalogue.departments.find(
    (department) => department.id === profile?.department_id,
  );
  const initialSemester = catalogue.semesters.find(
    (semester) => semester.id === profile?.current_semester_id,
  );
  const [collegeId, setCollegeId] = useState(
    initialDepartment?.college_id ?? "",
  );
  const [departmentId, setDepartmentId] = useState(
    profile?.department_id ?? "",
  );
  const [sessionId, setSessionId] = useState(
    initialSemester?.academic_session_id ?? "",
  );
  const [semesterId, setSemesterId] = useState(
    profile?.current_semester_id ?? "",
  );
  const [state, formAction] = useActionState(
    saveOnboardingAction,
    initialOnboardingActionState,
  );
  const departments = useMemo(
    () =>
      catalogue.departments.filter(
        (department) => department.college_id === collegeId,
      ),
    [catalogue.departments, collegeId],
  );
  const semesters = useMemo(
    () =>
      catalogue.semesters.filter(
        (semester) => semester.academic_session_id === sessionId,
      ),
    [catalogue.semesters, sessionId],
  );

  return (
    <form action={formAction} className="mt-8 space-y-6">
      <div className="grid gap-5 sm:grid-cols-2">
        <div className="space-y-2 sm:col-span-2">
          <label className="text-sm font-medium" htmlFor="full_name">
            Full name
          </label>
          <input
            className={fieldClassName}
            defaultValue={profile?.full_name ?? suggestedFullName}
            id="full_name"
            name="full_name"
            required
          />
        </div>

        <div className="space-y-2 sm:col-span-2">
          <label className="text-sm font-medium" htmlFor="matric_number">
            Matric number
          </label>
          <input
            autoCapitalize="characters"
            className={fieldClassName}
            defaultValue={profile?.matric_number ?? ""}
            id="matric_number"
            name="matric_number"
            required
          />
          <p className="text-xs text-muted-foreground">
            We will normalize spacing and letter casing when your profile is
            saved.
          </p>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="college_id">
            College
          </label>
          <select
            className={fieldClassName}
            id="college_id"
            name="college_id"
            onChange={(event) => {
              setCollegeId(event.target.value);
              setDepartmentId("");
            }}
            required
            value={collegeId}
          >
            <option value="">Choose a college</option>
            {catalogue.colleges.map((college) => (
              <option key={college.id} value={college.id}>
                {college.name} ({college.code})
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="department_id">
            Department
          </label>
          <select
            className={fieldClassName}
            disabled={!collegeId}
            id="department_id"
            name="department_id"
            onChange={(event) => setDepartmentId(event.target.value)}
            required
            value={departmentId}
          >
            <option value="">Choose a department</option>
            {departments.map((department) => (
              <option key={department.id} value={department.id}>
                {department.name} ({department.code})
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="level_id">
            Level
          </label>
          <select
            className={fieldClassName}
            defaultValue={profile?.level_id ?? ""}
            id="level_id"
            name="level_id"
            required
          >
            <option value="">Choose a level</option>
            {catalogue.levels.map((level) => (
              <option key={level.id} value={level.id}>
                {level.label}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="academic_session_id">
            Academic session
          </label>
          <select
            className={fieldClassName}
            id="academic_session_id"
            name="academic_session_id"
            onChange={(event) => {
              setSessionId(event.target.value);
              setSemesterId("");
            }}
            required
            value={sessionId}
          >
            <option value="">Choose a session</option>
            {catalogue.sessions.map((session) => (
              <option key={session.id} value={session.id}>
                {session.label}
              </option>
            ))}
          </select>
        </div>

        <div className="space-y-2 sm:col-span-2">
          <label className="text-sm font-medium" htmlFor="current_semester_id">
            Current semester
          </label>
          <select
            className={fieldClassName}
            disabled={!sessionId}
            id="current_semester_id"
            name="current_semester_id"
            onChange={(event) => setSemesterId(event.target.value)}
            required
            value={semesterId}
          >
            <option value="">Choose a semester</option>
            {semesters.map((semester) => (
              <option key={semester.id} value={semester.id}>
                {semester.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      {state.message ? (
        <p
          className="rounded-md bg-red-50 px-3 py-2 text-sm text-red-700"
          role="alert"
        >
          {state.message}
        </p>
      ) : null}

      <div className="flex justify-end">
        <SaveButton />
      </div>
    </form>
  );
}
