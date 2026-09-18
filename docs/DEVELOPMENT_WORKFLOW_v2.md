# Summit University Exam Practice Platform
## DEVELOPMENT_WORKFLOW.md

This document explains how the three developers will work on one product without turning the project into three separate implementations.

The agreed product and architecture documents are the shared reference point.

The workflow is structured around clear responsibilities, shared visibility and review so that work can move in parallel without drifting apart.

---

# 1. Core Working Principle

We are building one product in one codebase.

```text
ONE PRODUCT
    |
    +-- one GitHub repository
    +-- one agreed architecture
    +-- one shared database structure
    +-- one UI system
    +-- multiple feature branches
```

Parallel work should happen inside shared boundaries.

We should not build separate applications and try to combine them later.

---

# 2. Shared Source of Truth

The GitHub repository is the source of truth.

Each developer works from a local clone of the same repository.

```text
GitHub Repository
       |
       +-- Developer 1 local clone
       |
       +-- Developer 2 local clone
       |
       +-- Developer 3 local clone
```

The repository should contain:

```text
/docs
  PRODUCT_PLAN.md
  TEAM_OVERVIEW.md
  ARCHITECTURE.md
  DEVELOPMENT_WORKFLOW.md
  UI_GUIDE.md          # created during foundation work
```

Important product or architecture changes should be reflected in the relevant document.

---

# 3. Initial Foundation

Before major parallel development begins, the project needs a shared foundation.

One developer can take responsibility for assembling this first foundation so that the other developers are not starting from different assumptions.

This responsibility is about establishing the initial common structure.

The foundation should include:

```text
Project
- Next.js
- TypeScript
- Tailwind CSS
- shared UI component setup
- environment structure
- GitHub repository conventions

Supabase
- connection
- migrations
- basic RLS structure
- academic tables
- profiles
- courses
- course offerings
- practice sets
- questions
- attempts
- access model

UI
- app shell
- navigation
- typography
- spacing
- buttons
- inputs
- cards
- common states
- responsive rules
```

The database and foundation code must remain readable and accessible to all three developers.

No important system should exist only in one person's head.

---

# 4. Database Ownership

The database should remain understandable and reviewable by the whole team.

All developers should be able to:

- inspect the schema
- understand the relationships
- read migrations
- suggest schema changes
- identify problems
- review database changes

Schema changes should be made through version-controlled Supabase migrations.

Avoid making important permanent schema changes only through the Supabase dashboard.

Recommended structure:

```text
supabase/
  migrations/
```

Example:

```text
001_academic_structure.sql
002_profiles.sql
003_courses_and_offerings.sql
004_practice_content.sql
005_attempts.sql
006_payments_and_access.sql
```

Before a migration is merged, another developer should be able to understand what it changes and why.

Architecture-sensitive database changes should be discussed before implementation where practical.

---

# 5. UI Consistency

Parallel development should not begin with every developer independently designing their own pages.

A small shared UI foundation should exist first.

The team should agree on:

```text
App shell
Navigation
Page width
Typography
Spacing
Border radius
Buttons
Inputs
Cards
Modals / dialogs
Loading states
Empty states
Mobile behaviour
```

Shared components should be reused.

Example:

```text
Button
Input
Select
PageHeader
CourseCard
PracticeSetCard
EmptyState
QuestionNavigator
```

A developer can introduce a new reusable component when needed, but it should fit the existing UI system.

The goal is for the application to feel like one product even when different people build different features.

---

# 6. UI_GUIDE.md

During the foundation stage, create a lightweight:

```text
/docs/UI_GUIDE.md
```

It does not need to be a large design document.

It should record enough shared rules to prevent visual drift.

Example:

```text
Dashboard
- page container
- section spacing
- course card layout

Course Page
- title area
- access state
- practice set layout

Practice Page
- question area
- navigator
- actions
- mobile behaviour
```

If the UI direction changes, the guide can change with it.

---

# 7. Work Should Be Divided by Features

Avoid splitting work by random pages such as:

```text
Person A -> Login page
Person B -> Dashboard page
Person C -> Exam page
```

Instead, divide work into coherent features or domains.

Example:

```text
Course discovery
Practice experience
Payments and access
Written review
Progress
Content management
Admin tools
```

Each feature should have a clear boundary and expected behaviour before work begins.

---

# 8. Feature Contracts

Before someone starts a major feature, the team should know what that feature receives and what it produces.

Example:

```text
Course Page
INPUT:
courseOfferingId

USES:
course offering
active access
practice sets

OUTPUT:
student can open an available practice set
or see purchase options
```

Example:

```text
Practice Engine
INPUT:
practiceSetId

USES:
questions
attempt
student answers

OUTPUT:
submitted attempt
review
progress
```

This reduces overlap between developers.

---

# 9. Branch Workflow

Do not build major features directly on `main`.

Basic flow:

```text
main
 |
 +-- feature/course-catalogue
 |
 +-- feature/cbt-practice
 |
 +-- feature/payment-access
```

Before starting work:

```text
pull latest main
        |
        v
create feature branch
        |
        v
build
        |
        v
test
        |
        v
push branch
        |
        v
open pull request
```

Keep branches focused.

Avoid combining several unrelated features into one large branch.

---

# 10. Codex Workflow

Codex can work inside each developer's local clone.

```text
GitHub
   |
   v
Local Clone
   |
   v
Feature Branch
   |
   v
Codex + Developer
   |
   v
Test
   |
   v
Push
```

Before asking Codex to make significant changes:

- pull the latest agreed code
- work from the correct branch
- let Codex read the project docs
- give it a bounded task
- review what it changed

Codex should follow the architecture.

It should not be treated as the authority on the architecture.

Example instruction:

```text
Read:
docs/PRODUCT_PLAN.md
docs/ARCHITECTURE.md
docs/UI_GUIDE.md

Implement the requested feature inside the existing architecture.
Do not introduce a second access model or restructure unrelated features.
```

---

# 11. Review Flow

The developer who builds a feature is responsible for testing it before requesting review.

Normal flow:

```text
BUILD
  |
  v
SELF-TEST
  |
  v
PULL REQUEST
  |
  v
PEER REVIEW
  |
  v
INTEGRATION CHECK
  |
  v
MERGE
```

The purpose of review is not to prove that the builder is wrong.

It is to catch things that are easier for a second person to see.

Anyone can review anyone else's work.

---

# 12. What Review Should Check

A review should ask:

## Behaviour

- Does the feature actually work?
- Does it match the product plan?
- Are important states handled?

## Architecture

- Does it use the existing data model?
- Did it create a duplicate system unnecessarily?
- Does it respect access and security rules?

## UI

- Does it use the shared components?
- Does it feel like the same application?
- Does it work on mobile?

## Integration

- Does it break an existing feature?
- Does it change shared contracts?
- Does another feature need to be updated?

---

# 13. Architecture-Sensitive Changes

Some changes deserve discussion before they are merged.

Examples:

```text
database schema
authentication
course access
payments
attempt lifecycle
question structure
content publication
shared types
major routing changes
role/permission changes
```

For these changes, the team should understand the reason and consequences.

No developer should silently introduce a second way of doing something that already has an agreed system.

If there is a better approach, propose the change and update the architecture if the team agrees.

---

# 14. Integration Responsibility

At any point in development, one developer may handle integration for a set of parallel changes.

That includes checking that the pieces work together before they enter the shared main branch.

Integration work can include:

- checking conflicts
- checking shared contracts
- running the combined application
- checking migrations
- checking UI consistency
- checking that a change does not break another feature

Important integration decisions should still be visible and reviewable by the team.

---

# 15. Definition of Done

A feature is not done just because code has been written.

A useful definition is:

```text
Implemented
+
Self-tested
+
Matches agreed product behaviour
+
Uses agreed architecture
+
Uses shared UI rules
+
Reviewed
+
Works with current main branch
=
DONE
```

If a feature depends on another unfinished feature, that should be stated clearly.

---

# 16. Do Not Send Cleanup Work Downstream

A developer should not submit work with the expectation that another developer will make it usable.

Bad flow:

```text
generate code
    |
    v
push unfinished work
    |
    v
someone else repairs it
```

Preferred flow:

```text
build
  |
  v
understand what changed
  |
  v
test
  |
  v
clean obvious issues
  |
  v
submit for review
```

Reviewers may still find problems.

That is normal.

---

# 17. Shared Understanding

Important systems should be understandable by all three developers.

Examples:

```text
Course vs Course Offering
Profile vs Course Access
Practice Set vs Attempt
Payment vs Access
CBT vs Written flow
Content Submission vs Published Content
```

If only one person understands a critical part of the system, that is a project risk.

Documentation and readable migrations/code should reduce this.

---

# 18. Product Decisions

The product documents are the current agreed direction and can be updated when implementation reveals a better approach.

If implementation reveals a problem:

```text
Developer identifies issue
        |
        v
Team discusses
        |
        +-- existing direction still works -> continue
        |
        +-- better direction agreed -> update docs
```

The important thing is that the implementation and documentation stay aligned.

---

# 19. Mistakes and Corrections

The workflow should make corrections easy when a requirement is misunderstood, an edge case is missed, or a better implementation is found.

---

# 20. Suggested Early Build Sequence

Before large parallel feature work:

```text
MILESTONE 0
Repository
Docs
Next.js
Supabase
Shared environment structure

        |
        v

MILESTONE 1
Database foundation
Academic structure
Profiles
Courses / offerings
Practice model
Attempts
Access model
Basic RLS

        |
        v

MILESTONE 2
UI foundation
App shell
Shared components
UI_GUIDE.md

        |
        v

MILESTONE 3
First vertical slice

Login
  |
  v
Profile
  |
  v
One Course Offering
  |
  v
Access
  |
  v
One Practice Set
  |
  v
Submit
  |
  v
Review
  |
  v
Progress

        |
        v

MILESTONE 4
Written practice path

        |
        v

MILESTONE 5
Payments and bundle access

        |
        v

PARALLEL FEATURE EXPANSION
```

---

# 21. First Vertical Slice

The first major proof should be one complete journey.

Not many incomplete pages.

Example:

```text
Student signs in
      |
      v
Student profile exists
      |
      v
Relevant course appears
      |
      v
Test access exists
      |
      v
Practice Set opens
      |
      v
Student answers
      |
      v
Student submits
      |
      v
Review works
      |
      v
Progress is saved
```

Once this works, the team has a real shared foundation.

---

# 22. Shared Supabase Workflow

All three developers should work against the same agreed schema.

Recommended rules:

- migrations live in Git
- schema changes happen through migrations
- important seed data can also be version controlled
- RLS changes are reviewed like application code
- secrets are never committed
- database changes are pulled before dependent feature work starts

A shared development Supabase project can be used initially.

A separate production project should be introduced before launch.

---

# 23. Environment Variables

Use an example file:

```text
.env.example
```

It can contain variable names but no real secrets.

Example:

```text
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
PAYSTACK_SECRET_KEY=
NEXT_PUBLIC_PAYSTACK_PUBLIC_KEY=
```

Real values stay in each developer's local environment and the deployment platform.

---

# 24. Merge Conflicts

When branches conflict:

- do not blindly accept one side
- understand what both branches changed
- preserve the intended behaviour
- ask the developer who owns the affected feature when needed

For architecture-sensitive conflicts, resolve the underlying design question first.

---

# 25. Keeping Work Small

Prefer small, reviewable milestones.

Good:

```text
Add College-first course catalogue
Add course search
Add active course access check
```

Harder to review:

```text
Build the whole student side
```

Smaller work reduces merge conflicts and makes mistakes easier to locate.

---

# 26. Communication Before Coding

A short task definition before a significant feature can prevent hours of rework.

It should state:

```text
WHAT
What are we building?

WHY
What problem does it solve?

BOUNDARY
What is included?

NOT INCLUDED
What should not be changed?

CONTRACT
What existing system does it use?
```

This can be a GitHub issue, pull request description or short shared note.

---

# 27. Example Parallel Work

After the foundation is stable:

```text
Developer A
Course browsing and search
        |
        v
feature/course-catalogue


Developer B
CBT practice interface
        |
        v
feature/cbt-practice


Developer C
Access/payment integration
        |
        v
feature/payment-access
```

The exact assignments can change.

What matters is that all three features use:

- the same schema
- the same shared types
- the same UI system
- the same product rules

---

# 28. Roles Can Change

Responsibilities can shift between milestones.

Someone handling integration in one milestone may build a feature in the next, and another developer should be able to extend an existing subsystem from the documentation and code.

---

# 29. Final Working Model

```text
AGREE ON BEHAVIOUR
        |
        v
ASSIGN FEATURE
        |
        v
BUILD ON FEATURE BRANCH
        |
        v
SELF-TEST
        |
        v
PEER REVIEW
        |
        v
INTEGRATION CHECK
        |
        v
MERGE TO MAIN
        |
        v
EVERYONE PULLS UPDATED MAIN
```

Nobody should work from a private version of the product for long periods.

The shared repository and documentation should keep important system knowledge visible while parallel work stays organised.

---

# 30. Starting Point

Once the team agrees on:

- PRODUCT_PLAN.md
- ARCHITECTURE.md
- DEVELOPMENT_WORKFLOW.md

development can begin with the shared foundation.

The next practical work is:

```text
1. Create/configure the shared GitHub repository
2. Add the agreed docs
3. Create the Next.js project
4. Configure Supabase
5. Create the first version-controlled migrations
6. Build the shared UI foundation
7. Prove the first vertical slice
8. Start controlled parallel development
```
