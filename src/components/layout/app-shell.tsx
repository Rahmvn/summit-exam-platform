import type { ReactNode } from "react";

type AppShellProps = {
  children: ReactNode;
};

export function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-background">
      <header className="border-b bg-card">
        <div className="mx-auto flex h-16 max-w-7xl items-center px-6">
          <span className="text-sm font-semibold tracking-tight">
            Summit Exam Platform
          </span>
        </div>
      </header>
      <main>{children}</main>
    </div>
  );
}
