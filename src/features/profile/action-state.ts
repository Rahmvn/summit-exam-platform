export type OnboardingActionState = {
  status: "idle" | "error";
  message: string;
};

export const initialOnboardingActionState: OnboardingActionState = {
  status: "idle",
  message: "",
};
