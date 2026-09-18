export default function HomePage() {
  return (
    <section className="mx-auto flex min-h-[calc(100vh-4rem)] max-w-5xl items-center px-6 py-16">
      <div className="max-w-2xl space-y-4">
        <p className="text-sm font-medium text-primary">Project foundation</p>
        <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
          Summit Exam Platform
        </h1>
        <p className="max-w-xl text-base leading-7 text-muted-foreground sm:text-lg">
          The shared application shell is ready. Product features will be added
          through the project&apos;s domain-based modules.
        </p>
      </div>
    </section>
  );
}
