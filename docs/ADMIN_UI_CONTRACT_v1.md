# Summit Exam Platform
## Admin UI Contract v1

**Status:** Authoritative V1 Admin product and interaction contract

**Purpose:** Define the Admin information architecture, task flows, lifecycle behavior, responsive rules, states, and safety expectations that frontend and backend contracts must support.

This is a product experience contract. It is not a visual mockup, database schema, route implementation, RPC specification, or implementation plan.

---

# 1. Core Admin Principle

Summit has a broad academic and content model. V1 Admin exposes only the complexity required for the operator's current task.

```text
BIG PLATFORM MODEL
        |
        v
SMALL V1 SURFACE
        |
        v
SIMPLE OPERATOR EXPERIENCE
```

Database tables do not become navigation items merely because they exist.

The interface should:

- organize work around durable academic entities and operator tasks;
- explain impact before consequential actions;
- keep routine Draft authoring fast;
- translate integrity rules into actionable language;
- preserve history without exposing implementation detail;
- leave room for future commerce, support, and narrower roles without pretending they exist in V1.

---

# 2. V1 Role and Authorization Assumptions

V1 has exactly two roles:

- Candidate
- Admin

There is no Content Manager role or visible permission matrix in V1.

Admin authority comes from explicit Admin membership and is independent of:

- Candidate academic profile;
- Course Assignment;
- Candidate Course Access.

An Admin does not automatically receive Candidate access to Course Offerings. Admin navigation visibility is not authorization; every Admin read or mutation must be protected by trusted server-side authorization.

Future roles may be introduced later without changing this V1 contract.

---

# 3. Admin Information Architecture

V1 top-level destinations are:

1. Courses
2. Review
3. Candidates
4. Academic

`/admin` lands on Courses.

Do not add these as top-level V1 destinations:

- Dashboard
- Questions
- Sources
- Access
- Payments
- Pricing
- Support
- Reports
- Activity

Questions, Sources, and access operations remain available inside the entities that give them context. Review is a cross-Offering work queue, not an independent review subsystem.

---

# 4. Admin Shell

Admin and Candidate share the same product language:

- typography;
- controls and form behavior;
- radii and spacing vocabulary;
- status language;
- dialog and sheet primitives;
- neutral canvas and white working surfaces;
- deep green primary actions;
- restrained gold accents.

Admin may use denser tables and wider working areas than Candidate.

## Desktop

- Use a left sidebar, approximately 230–250px where practical.
- Give operational work more horizontal space than the Candidate shell.
- Do not add a giant top navigation bar.
- Do not show generic global search unless a real global search contract exists.
- Search belongs inside the current destination.

## Mobile

- Use a compact top bar.
- Open Admin navigation through a drawer or sheet.
- Do not use Candidate-style bottom navigation.
- Make quick review, Candidate, access, and status tasks work well.
- Dense assembly and import flows may be desktop-first, but must remain navigable and fail gracefully on mobile.

---

# 5. Navigation and Routing

Prefer durable entity routes instead of deeply nested URL trees.

Conceptual routes:

```text
/admin
/admin/courses
/admin/courses/[courseId]
/admin/offerings/[offeringId]
/admin/practice-sets/[practiceSetId]
/admin/questions/[questionId]
/admin/review
/admin/candidates
/admin/candidates/[candidateId]
/admin/academic
```

Breadcrumbs communicate the academic hierarchy even when URLs remain shallow:

```text
Courses
› CSC 203
› 2026/2027 · First Semester
› Set 2
› Question 14
```

Large editing and inspection tasks use pages. A short confirmation, picker, or bounded form may use a dialog or sheet. Temporary overlays must not create fake durable route state.

---

# 6. Courses Landing

Courses is the default Admin destination and contains two views within the same area:

1. Courses
2. Offerings

## Courses view

The Courses view manages stable academic Course identities. It should provide:

- search by Course code or title;
- useful academic filters where they improve discovery;
- Offering count;
- Create Course;
- a durable route to each Course.

## Offerings view

The Offerings view is a cross-Course operational view for work such as preparing a Semester across many Courses. Useful filters include:

- Academic Session;
- Semester;
- College;
- Department;
- Level;
- exam mode;
- active/inactive state.

Offerings is not another top-level sidebar destination.

---

# 7. Course Workspace

A Course is the stable academic identity across Academic Sessions. Its page remains intentionally thin.

It may contain:

- Course code;
- title;
- description if supported by the domain contract;
- list of Course Offerings;
- Create Offering.

Do not place these directly on the Course page:

- Sources;
- Practice Sets;
- Questions;
- access management;
- publication controls.

Those operations belong to a specific Course Offering.

---

# 8. Course Offering Workspace

Course Offering is the main operational workspace. It combines:

- Course;
- Academic Session and Semester;
- exam mode;
- Department + Level Course Assignments;
- practice configuration;
- Practice Sets;
- Sources;
- Course Access context.

Recommended tabs:

1. Overview
2. Course assignment
3. Practice Sets
4. Sources
5. Access

Each tab answers a distinct question. Do not turn the Offering route into one monolithic page.

## Overview

Overview answers: **What is this Offering, and how does practice work?**

Display and, where supported, configure:

- Academic Session;
- Semester;
- exam mode;
- expected Questions per Practice Set;
- practice duration;
- active/inactive Offering state.

Admin enters duration in a human-friendly unit such as minutes. Internal systems may represent duration in seconds.

Expected Question count and practice duration belong to the Course Offering. V1 has no per-Practice-Set override.

Changing duration affects future Attempts only. Existing Attempts retain their frozen duration and authoritative deadline.

Changing expected Question count must be blocked when the new value would
invalidate any Practice Set currently in Review or Published. The impact result
must identify every affected Review or Published Set and explain why the change
cannot proceed. Draft Practice Sets may adapt to the new Offering requirement.

Exam mode is not an ordinary harmless select after incompatible content exists. The UI must explain and enforce the restriction supplied by the trusted backend contract.

---

# 9. Offering Activity

Course Offering activity is independent of Course Access, Practice Set lifecycle, and Course Assignment.

Offering availability and content publication are separate. An inactive Course
Offering may contain Draft, Review, and Published Practice Sets. Offering
activity is not required merely to send a structurally complete Practice Set to
Review or to Publish a Set that is currently in Review and passes readiness.
This permits future or paused Offerings to be fully prepared and Published
without making them Candidate-usable.

Starting new practice ultimately requires all of these:

- a positive centralized effective-access result;
- active Course Offering;
- active and Published Practice Set;
- passing Practice Set readiness and integrity.

Deactivating an Offering:

- prevents new Attempts;
- does not revoke Course Access Grants;
- does not delete content;
- does not erase historical Attempts;
- permits an existing in-progress Attempt to finish subject to its own authoritative deadline.

Require confirmation with concise impact copy. Show related Published Sets or active access context when that materially changes the decision.

---

# 10. Course Assignment

Use the Admin-facing label **Course assignment**. Internal domain code may continue to use audience terminology.

Course assignment answers: **Which Department + Level groups is this Course Offering academically relevant to?**

Each assignment is exactly:

```text
Department + Level
```

One Offering may have multiple assignments, including different Levels across Departments.
It may also validly have zero assignments. No special mode or default assignment
is required.

Example:

```text
Software Engineering · 200 Level
Computer Science · 200 Level
Cyber Security · 300 Level
```

College is inferred from Department. It may provide picker context, but should not be independently selected as recommendation relevance.

Course Assignment determines:

- Candidate recommendation relevance when Department, Level, and current Semester match;
- default academic fit;
- suggestions for future academic bundle composition.

It does not grant Course Access.

Removing an assignment changes relevance but does not:

- revoke existing Course Access;
- remove an off-profile purchase or grant;
- prevent direct catalogue discovery where otherwise applicable;
- block Draft -> Review or Review -> Published;
- invalidate Published content;
- terminate an in-progress Attempt;
- invalidate historical Attempts;
- silently rewrite a future package or historical purchase composition.

Use concise confirmation when the assignment is active or feeds visible recommendations.

---

# 11. Practice Configuration

The Offering owns:

- expected Questions per Practice Set;
- practice duration;
- exam mode.

Every Practice Set inherits these values. The workspace should distinguish inherited configuration from editable Practice Set properties.

Practice duration is required for timed practice. The authoritative server operation snapshots duration and deadline when an Attempt starts; the Admin UI never edits an existing Attempt deadline by changing Offering configuration.

Configuration mutations are consequential and require server validation and append-only audit. The UI should show an impact summary before a change that affects existing content readiness.

---

# 12. Practice Sets

Practice Set is the sole content publication unit.

Its complete lifecycle is:

```text
draft -> review -> published -> archived
```

An Archived Practice Set:

- is unavailable for new Attempts;
- is not presented as available Candidate practice;
- preserves submitted Attempts and historical review;
- does not destroy frozen Attempt snapshots;
- does not terminate an already in-progress Attempt;
- permits that existing Attempt to finish subject to its own authoritative deadline.

Do not add stored states such as:

- Approved;
- Ready to Publish;
- Changes Requested;
- Rejected.

“Ready to publish” is a derived readiness result, not a lifecycle state.

The Practice Set list should show only useful operational information:

- title;
- lifecycle state;
- current Question count / expected Question count;
- a relevant action such as Open, Continue, or Review.

Avoid decorative statistics.

## Creation

Creation should be lightweight. Default suggestions may use Set 1, Set 2, and Set 3, but the title remains editable. After creation, navigate directly to the new Practice Set workspace.

## Workspace

The Practice Set workspace is the primary authoring surface. It should show:

- title;
- lifecycle status;
- current / expected Question count;
- inherited duration;
- inherited exam mode;
- ordered Questions;
- Add Question;
- Import Questions;
- readiness when relevant;
- Preview as Candidate;
- the valid lifecycle action for the current state.

The Admin mental model is:

```text
Course
  -> Course Offering
      -> Practice Set
          -> add or import Questions
```

Do not expose a Question Pool-first V1 workflow. Questions remain reusable underlying entities through mappings.

---

# 13. Question Authoring

Questions do not have an editorial or publication lifecycle in V1. Do not expose Question states such as Draft, Review, Ready, Published, or Archived.

Question eligibility is derived from:

- operational active state;
- structural validity;
- exam-mode-specific required data;
- same-Offering integrity;
- valid Practice Set mapping.

`questions.is_active` is an operational kill switch, not a second publication workflow.

## Manual authoring

Adding one Question opens a dedicated Question editor route, not a cramped modal.

CBT authoring supports:

- Question text;
- an arbitrary supported number of ordered options;
- exactly one valid correct option under the current model;
- optional explanation;
- optional reference;
- optional Source/provenance association.

Do not hardcode A–D into the domain model. A, B, C, D, E, and similar labels are presentation derived from position.

Written authoring supports:

- Question text;
- model answer;
- ordered key points;
- optional reference;
- optional Source/provenance association.

Saving returns naturally to the Practice Set workflow and preserves the operator's location.

## Ordering

Question order belongs to the Practice Set mapping.

Desktop may offer drag-and-drop, but it must also offer keyboard-accessible actions:

- Move up;
- Move down;
- Move to position.

Persist reordering as one coherent operation, not a series of unrelated writes.

## Removing from a Set

Removing a Question from a Practice Set is not deletion or deactivation of the underlying Question. Confirmation copy should state:

- the Question is removed from this Set;
- other Practice Sets using it are unaffected;
- the underlying Question remains available unless separately deactivated through a controlled operation.

---

# 14. Bulk Question Import

Bulk Question Import is V1. Its primary entry point is inside a Practice Set.

Planned formats:

- CSV;
- XLSX;
- JSON.

Required experience:

```text
Upload
  -> Parse
  -> Validate
  -> Preview
  -> Show row-level errors and warnings
  -> Correct where practical
  -> Confirm
  -> Atomic commit
```

The confirmed import creates all Questions and ordered mappings atomically. If it fails, it creates neither partial Questions nor partial mappings.

Uploaded data cannot choose trusted Offering identity or exam mode. Those come from the Practice Set and Course Offering context.

If uploaded Questions exceed the remaining slots, never truncate silently. Explain:

- expected count;
- existing count;
- remaining slots;
- uploaded count.

The Admin must deliberately correct the file, remove rows, or leave the import without committing.

A selected Source may be associated with every imported Question. Mixed per-row provenance may be supported when the import contract allows it. Source is never mandatory merely to complete an otherwise valid import.

---

# 15. Readiness

Admin sees an actionable readiness result, not raw constraints or database errors.

Readiness conceptually verifies:

- valid Offering relationship;
- configured expected Question count;
- configured practice duration;
- exact Question count;
- same-Offering Question and mapping integrity;
- active Questions;
- unique, valid, contiguous mapping positions;
- valid CBT options;
- exactly one valid CBT correct answer under the current model;
- required Written model-answer and key-point data;
- any other authoritative structural integrity rule.

Zero Course Assignments is not a structural readiness blocker. It produces a
warning that the Offering will not appear in Department + Level profile
recommendations. Authorization remains governed by the effective-access policy
and Course Access, not Course Assignment.

Offering activity is Candidate-availability state, not a content-readiness
requirement for Send for Review or Publish. It remains required when a Candidate
starts a new Attempt.

Source, explanation, and reference are not universal readiness blockers unless a later explicit product rule makes them required.

The result should contain:

- Ready or Not ready;
- blockers;
- warnings;
- links to affected Questions or configuration where possible;
- a plain-language next action.

Frontend preflight is helpful but never authoritative.

---

# 16. Send for Review

A Practice Set may move from Draft to Review only when structural readiness passes.

Review is for quality inspection, not for completing structurally broken content.

Sending for Review requires:

- server-authoritative readiness validation;
- concise confirmation;
- clear notice that normal editing becomes restricted in Review;
- an append-only audit record.

Do not introduce reviewer assignment, ownership, SLA, or multi-level approval machinery.

---

# 17. Review

Review is both:

- the Practice Set lifecycle state; and
- a lightweight cross-Offering queue at `/admin/review`.

The global Review destination is a filtered work queue, not a separate Review entity.

Useful queue context includes:

- Course and Offering;
- Practice Set title;
- exam mode;
- Question count;
- readiness result;
- time sent to Review where available.

Opening an item uses the same Practice Set review workspace reached from the Course hierarchy.

Review emphasizes inspection. The reviewer may:

- move through Questions;
- inspect options, correct answers, explanations, model answers, key points, and provenance;
- Preview as Candidate;
- Send back to Draft;
- Publish.

Sending back to Draft requires a reason and audit. It does not create a stored “Changes Requested” state.

---

# 18. Preview as Candidate

Preview should reuse real Candidate presentation components where practical so layout and content problems are visible before publication.

Preview must:

- create no Attempt;
- create no Candidate answer or progress;
- affect no analytics;
- require no fake Candidate access grant;
- clearly identify Preview mode;
- prevent confusion with a real timed practice session.

Preview helps catch:

- long or malformed Question text;
- option rendering problems;
- Written model-answer/key-point problems;
- broken references or material;
- mobile and wrapping issues.

---

# 19. Publishing and Published Corrections

## Publish

Publishing is available only from Review. The authoritative publish operation must re-run readiness.

If readiness changed, publication fails safely and returns actionable blockers. UI preflight never overrides the server.

Publish confirmation identifies:

- Course Offering;
- exam mode;
- Question count;
- practice duration;
- that Candidates with effective authorization can use the Set.

Course Assignment must not be described as Course Access.

## Published corrections

Frozen Attempt snapshots preserve historical Candidate truth. Question reuse means a live Question change may affect several Published Practice Sets.

V1 rules:

- harmless typo, formatting, or reference corrections may eventually use an impact-aware audited in-place correction;
- substantive correction must not silently mutate every Published Set using the Question;
- substantive correction uses controlled replacement and explicit remapping of selected Sets;
- affected Practice Sets are shown and explicitly confirmed;
- readiness is revalidated;
- reason and audit are required.

V1 does not introduce formal Question versions, Practice Set versions, or a release subsystem. The exact harmless-versus-substantive boundary remains an open backend/product contract.

---

# 20. Sources

Sources are Offering-scoped in V1 and live under the Offering workspace. There is no top-level Sources destination or global Source library.

Supported source concepts may include:

- lecturer PDF/material;
- lecture material;
- student jotting;
- past question;
- lecture question;
- manual material;
- AI-generated-from-trusted-material provenance;
- another supported type.

The Sources tab may show:

- name/title;
- type;
- Offering;
- material or reference;
- usage count;
- active state where supported;
- edit action.

Questions may have many-to-many provenance relationships with Sources from the same Offering. Provenance is desirable where possible but not universally mandatory.

Sources have no publication lifecycle. Avoid destructive deletion of referenced Sources; deactivate where supported and preserve provenance history. The V1 surface remains Offering-scoped without preventing a future reuse design.

---

# 21. Candidates

Candidates is a top-level Admin destination.

The directory follows least-data visibility. Suggested default columns:

- Name;
- Department;
- Level;
- active Course Access Grant count.

Search supports name and matric number where available. Useful filters include Department, Level, and presence of an active grant.

Do not expose by default:

- scores;
- Attempt history;
- last login;
- payment history;
- email history;
- support history;
- excessive operational metadata.

## Candidate detail

Candidate detail is a durable route with initial tabs:

1. Profile
2. Access

Profile shows useful identity and academic context. It is not a giant arbitrary Admin-edit form. Future controlled profile correction may be added only after a real operational need and trusted contract exist.

Candidate profile changes never revoke or shorten Course Access Grants.

---

# 22. Course Access Administration

Course Access is independent of recommendation relevance and Course Assignment.

A Candidate may receive access to any Course Offering, including an Offering outside their current academic profile. An individual Offering purchase never requires a Department/Level package purchase.

Off-profile access is valid. The UI may quietly explain that an Offering is outside the Candidate's current academic profile, but must not block the operation.

Manual Admin grant, extension, and revocation are V1.

They support:

- QA and testing;
- early cohorts;
- complimentary access;
- support and manual reconciliation;
- future institutional workflows.

## Contexts

Candidate detail → Access shows:

- current grants;
- previous, expired, or revoked grants;
- Grant;
- Extend;
- Revoke.

Offering → Access shows:

- platform-wide effective-access context;
- Candidates with individual grants;
- grant and revoke operations from the Offering context.

Both contexts use the same trusted backend contracts. There is no top-level Access destination.

## Grant

The grant dialog collects:

- Candidate or Offering, depending on entry context;
- start;
- expiry;
- mandatory reason.

Show sufficient Offering and Candidate context to reduce accidental grants.

Do not silently create overlapping active grants. If active access already exists, guide the Admin toward extension or another explicit operation. Exact overlap and idempotency semantics remain backend-contract work.

## Extend

Extension is an explicit operation, not a silent duplicate grant. Show the existing effective period, proposed expiry, mandatory reason, and resulting period before confirmation.

## Revoke

Revocation requires confirmation, mandatory reason, and audit.

Revocation:

- prevents new Attempts when a grant is required—under `grant_required` or at/after a `free_until` cutoff—and no other active effective grant applies;
- does not erase historical Attempts;
- does not invalidate an in-progress Attempt;
- permits that Attempt to finish subject to its own deadline.

Routine V1 revocation does not require typed confirmation.

---

# 23. Platform Access Policy

The initial access policy is platform-wide and supports exactly:

```text
free
free_until
grant_required
```

## Free

- All authenticated Candidates may start otherwise eligible Published content.
- Individual Course Access Grants are not required.
- Do not create fake grants for every Candidate.

## Free until

- Before the authoritative cutoff, otherwise eligible authenticated Candidates may start without an individual Course Access Grant.
- At or after the cutoff, starting a new Attempt requires an active effective Course Access Grant.
- The server evaluates the cutoff without changing the stored policy mode; no scheduler, Admin action, or database mutation is required at the cutoff.
- An Attempt validly started before cutoff remains completable subject to its own snapshotted deadline.
- Individual grants remain separate and may authorize new Attempts after the free window ends.

## Grant required

- Starting a new Attempt requires an active effective Course Access Grant.

The runtime returns one centralized effective-access result. The browser must not independently combine:

- policy mode;
- cutoff;
- individual grant;
- Offering activity.

Offering → Access must distinguish platform-wide effective access from individual grants. Examples:

```text
Platform access: Free for all Candidates

Platform access: Free until 30 September 2026
Individual Course Access Grants: 18

Platform access: Individual grant required
```

Do not imply that individually granted Candidates are the only Candidates who can practise under `free` or before a `free_until` cutoff.

Access-policy configuration is a consequential platform-level Admin operation. Its exact V1 placement is intentionally unresolved; do not invent a Settings destination until that decision is made. Every future policy change requires server authorization, impact confirmation, reason where appropriate, and audit.

---

# 24. Future Commerce Boundary

Payments, pricing, and bundle management are not V1 Admin surfaces.

The Admin contract must nevertheless preserve these future rules:

- commerce supports individual Course Offering purchase;
- commerce supports academic bundle/package purchase;
- both models coexist;
- one purchase may contain several Course Offerings;
- a bundle is scoped by Department, Level, Academic Session, and Semester;
- bundle composition is an explicit list of Course Offerings;
- Course Assignment may suggest composition but never silently rewrites an existing package or purchase snapshot;
- trusted package processing creates Course Access Grants for every included Offering;
- payment itself is never authorization.

Do not design Payment, Pricing, or Bundle management UI in V1.

---

# 25. Academic Management

Academic is one top-level destination with internal areas:

- Colleges;
- Departments;
- Levels;
- Sessions & Semesters.

Academic owns structural reference data. Courses owns Course and Course Offering operations.

Do not create a separate sidebar destination per academic table or turn Academic into another Course-management interface.

## Colleges

Manage:

- name;
- code;
- active/deactivated state.

Use a simple semantic table/list with dialog-based creation and editing where appropriate. Referenced Colleges should generally be deactivated, not hard-deleted.

## Departments

Manage:

- College;
- name;
- code;
- active/deactivated state.

Provide search and College filtering. Deactivation must not erase Candidate profile history, Course Assignments, Attempts, Course Access, or historical academic records. Show impact before consequential deactivation.

## Levels

Levels are configurable and must not be hardcoded to 100–400.

Manage:

- code/value;
- display label;
- sort order;
- active state.

Keep Level management small and operational.

## Sessions & Semesters

Academic Session and its Semesters belong together operationally.

The current authoritative model stores a Candidate's current Semester on the Candidate profile. Recommendation uses that Candidate value together with Department and Level. It does not currently define a platform-global `is_current` Semester.

Therefore V1 Academic UI must not invent a global current-Semester toggle. Whether Summit later adds one platform-wide current Semester, how it interacts with Candidate profile state, and who controls it are open product and architecture decisions. Any future bulk or platform-wide change would be consequential, must preserve Course Access, and would require confirmation and audit.

---

# 26. Archive, Deactivate, and Delete

Avoid destructive deletion of referenced domain data.

Prefer the domain-appropriate operation:

- archive for Practice Set lifecycle;
- deactivate for Course Offerings, Questions, Sources, and academic reference data where supported.

Do not force one word across entities when the meanings differ.

No Admin action may erase or silently corrupt:

- frozen Attempts;
- Candidate answer history;
- Course Access history;
- historical academic relationships;
- provenance required to understand published content.

Impact-dependent actions should show an impact preview before confirmation.

---

# 27. Admin Audit and Consequential Actions

Append-only Admin audit must exist before consequential Admin mutation APIs are made available. No Activity or audit-log UI is required in V1.

At minimum audit:

- Practice Set lifecycle transitions;
- Course Access grant, extension, and revocation;
- academic structure mutations;
- Offering configuration changes;
- Offering activation/deactivation;
- consequential Course Assignment changes;
- substantive Published-content correction or replacement;
- platform access-policy changes;
- Admin membership changes when those APIs exist.

Harmless Draft edits should not receive excessive ceremony unless a later authoritative backend contract requires it.

Use confirmation, mandatory reason, and audit where appropriate for:

- Course Access revocation;
- manual access grants and extensions;
- substantive Published-content correction;
- sending Review content back to Draft;
- impactful deactivation;
- future access-policy changes.

Do not use typed confirmation for routine V1 operations unless the action becomes genuinely destructive. Never expose raw database or Supabase errors to the operator.

---

# 28. Responsive Behavior

These tasks should work very well on mobile:

- Admin navigation;
- Review queue;
- Practice Set review and inspection;
- Candidate search and detail;
- access grant, extension, and revoke;
- quick Offering status checks.

These should remain usable on mobile:

- Course and Offering creation;
- Course Assignment management;
- Academic Structure edits;
- simple Source management.

These may be desktop-first:

- Question authoring;
- Written model-answer and key-point editing;
- bulk import;
- Practice Set assembly and reordering;
- complex Source uploads.

Desktop-first does not mean broken mobile. Preserve navigation, context, readable content, and a clear explanation when a dense operation is better completed on a larger screen.

---

# 29. Accessibility

Every Admin surface requires:

- clearly visible focus;
- genuine buttons and links;
- semantic tables for tabular information;
- persistent labels for controls;
- status communicated by text, not color alone;
- a keyboard alternative to drag-and-drop Question ordering;
- properly labelled dialogs and sheets;
- Escape dismissal where appropriate;
- focus containment and return after overlays;
- reasonable touch targets;
- wrapping and overflow handling for long Course and Question text;
- reduced-motion support;
- meaningful loading, empty, error, and saving states.

Consequential confirmation copy must be understandable without relying on color, icons, or hidden hover content.

---

# 30. Shared States

Use a consistent Admin state vocabulary:

| State | Required behavior |
|---|---|
| Loading | Restrained skeleton matching the expected layout |
| Empty | Explain what is absent and provide the valid next action |
| No search results | Preserve search context and offer clear/reset |
| Error | Plain-language explanation, retry or recovery action |
| Offline | Quiet persistent state where network work matters |
| Saving | Local, non-blocking progress where safe |
| Saved | Subtle confirmation |
| Save failed | Visible error without pretending persistence succeeded |
| Session expired | Preserve safe context and offer sign-in |
| Offering unavailable | State whether inactive, missing, or unauthorized |
| Practice Set not ready | Show blockers and links to fixes |
| Import validation error | Identify row, field, problem, and next action |
| Import transaction failure | Confirm that nothing was partially committed |
| Access policy: free | Explain platform-wide access; do not imply grants are required |
| Access policy: free_until | Show the cutoff, automatic post-cutoff grant requirement, and separate grants |
| Access policy: grant_required | Show grant state and valid Admin actions |

Messages should say what the operator can do next. Never show a success state before the authoritative operation succeeds.

---

# 31. URL and UI State

Good URL state includes:

- Course and Offering filters;
- Session and Semester filters;
- search query;
- Review queue filters;
- Candidate search;
- pagination;
- selected durable workspace tab where useful;
- durable record identity.

Do not encode:

- temporary confirmation modal state;
- transient form values;
- short-lived picker sheets;
- toast or saving state.

Refreshing a durable route should restore enough context to continue work safely.

---

# 32. V1 Exclusions

The following are not implemented V1 Admin surfaces:

- Dashboard or analytics;
- Payment management;
- Pricing management;
- Bundle management;
- Support ticketing;
- email or campaign center;
- Activity or audit-log UI;
- global Question Pool-first workflow;
- global Source library;
- formal Question versioning;
- formal Practice Set versioning;
- release subsystem;
- reviewer assignment or SLA system;
- Content Manager role;
- detailed V1 permission matrix;
- per-Practice-Set duration or Question-count overrides;
- complex Candidate Attempt investigation;
- arbitrary Candidate profile editing;
- global search;
- decorative statistics.

An exclusion does not weaken the underlying security, audit, integrity, or historical-preservation requirement.

---

# 33. Open Product and Backend Decisions

Do not guess these during frontend implementation:

1. Exact placement of platform access-policy configuration.
2. Which Admins may change that policy operationally once a narrower permission model exists.
3. Exact `free_until` cutoff timezone and backend implementation of the authoritative cutoff boundary.
4. Whether a future platform-global current Semester is needed, and how it would interact with Candidate `current_semester_id`.
5. Exact grant overlap, extension, and idempotency semantics.
6. Exact harmless-versus-substantive Published correction boundary.
7. Exact backend representation for controlled Question replacement/remapping without formal versioning.
8. Supported correction experience for import rows before atomic commit.
9. Exact Source upload/storage behavior and future reuse boundary.
10. Exact future commerce pricing, duration, discounts, and package editing/snapshot mechanism.

Frontend work that depends on one of these decisions must stop at the contract boundary rather than inventing behavior.

The current schema does not yet supply every trusted Admin mutation, readiness, audit, timed-practice configuration, or effective-access-policy contract described here. That is a backend-contract dependency, not permission for the browser to bypass the requirement.

The current practice-content migration also retains a `questions.status` column
with publication-like values. The locked product model supersedes that field's
UI meaning: V1 Admin must not expose it as a Question lifecycle. Any later schema
reconciliation requires separately authorized backend work.

---

# 34. Admin Frontend Acceptance Checklist

## Shell and navigation

- [ ] `/admin` lands on Courses.
- [ ] Desktop uses the Admin sidebar and an appropriately wide working area.
- [ ] Mobile uses a compact top bar and drawer/sheet, not Candidate bottom navigation.
- [ ] Only Courses, Review, Candidates, and Academic are top-level V1 destinations.
- [ ] Admin authorization is server-gated and independent of Candidate profile/access.

## Courses and Offerings

- [ ] Courses catalogue supports code/title search, useful filters, Offering counts, and Create Course.
- [ ] Offerings cross-Course view supports Session, Semester, College, Department, Level, and useful operational filters.
- [ ] Course route remains thin and links to durable Offering routes.
- [ ] Offering route separates Overview, Course assignment, Practice Sets, Sources, and Access.
- [ ] Long Course titles and metadata wrap without breaking layout.

## Course Assignment and practice configuration

- [ ] One Offering can display and manage multiple Department + Level assignments.
- [ ] Zero assignments is valid and appears as a recommendation-visibility warning, not a Review or Publish blocker.
- [ ] College is contextual and never independently grants recommendation relevance.
- [ ] Assignment changes never imply Course Access changes.
- [ ] Expected Question count and duration are clearly Offering-level.
- [ ] No per-Set override is exposed.
- [ ] Duration changes explain that existing Attempts retain snapshots.
- [ ] Expected-count changes that would invalidate Review or Published Sets are blocked and identify every affected Set.
- [ ] Draft Sets may adapt to a changed Offering-level expected count.
- [ ] Offering inactivity does not block structurally valid Review or Publish operations.
- [ ] Offering inactivity still blocks Candidate starts.

## Practice Sets and Questions

- [ ] Practice Set creation is lightweight and opens the workspace.
- [ ] Lifecycle is exactly Draft, Review, Published, Archived.
- [ ] Archived Sets are unavailable for new practice while preserving submitted, reviewable, frozen Attempt history.
- [ ] Archiving does not terminate an in-progress Attempt, which remains governed by its deadline.
- [ ] Question creation uses a dedicated editor.
- [ ] No Question publication lifecycle is exposed.
- [ ] CBT supports ordered variable-count options without hardcoded A–D storage assumptions.
- [ ] Written supports model answer and key points.
- [ ] Removing a Question distinguishes mapping removal from underlying deactivation.
- [ ] Reordering has a keyboard-accessible alternative and saves coherently.
- [ ] Exact Question count is enforced before Review and Publish.

## Bulk import

- [ ] CSV, XLSX, and JSON appear only when their parser contracts exist.
- [ ] Upload, validation, preview, and confirmation are distinct steps.
- [ ] Row-level errors and warnings are actionable.
- [ ] Slot overflow is explained and never silently truncated.
- [ ] Transaction failure explicitly confirms that no partial import occurred.
- [ ] Uploaded rows cannot override Offering identity or exam mode.

## Readiness, Review, Preview, and Publish

- [ ] Readiness shows Ready/Not ready, blockers, warnings, and fix links.
- [ ] Send for Review fails when structural readiness fails.
- [ ] Review queue opens the same Practice Set workspace used by the hierarchy.
- [ ] Review introduces no assignment, SLA, ownership, or extra lifecycle state.
- [ ] Send back to Draft requires a reason.
- [ ] Candidate Preview creates no Attempt, progress, or analytics.
- [ ] Publish is available only from Review and revalidates server-side.
- [ ] Publish confirmation shows Offering, mode, count, duration, and Candidate impact.
- [ ] Published correction shows reuse impact and requires controlled selection, reason, revalidation, and audit.

## Sources

- [ ] Sources are Offering-scoped and have no top-level navigation.
- [ ] Source is optional for otherwise valid Question authoring/import.
- [ ] Provenance associations stay within the Offering.
- [ ] Source has no publication lifecycle.

## Candidates and access

- [ ] Candidate list follows least-data visibility.
- [ ] Candidate detail exposes Profile and Access tabs only for initial V1 scope.
- [ ] Off-profile Course Access is permitted and not labelled invalid.
- [ ] Grant, Extend, and Revoke are available from Candidate context.
- [ ] Offering Access uses the same trusted contracts.
- [ ] Grant/extension detects existing active access and does not silently overlap.
- [ ] Revoke requires confirmation, reason, and audit.
- [ ] Revocation preserves history and in-progress Attempt completion subject to deadline.
- [ ] `free`, `free_until`, and `grant_required` are presented distinctly.
- [ ] `free_until` automatically requires an active effective grant for new starts at or after cutoff.
- [ ] No manual policy switch is required when the `free_until` cutoff is reached.
- [ ] `free` and pre-cutoff `free_until` do not misleadingly imply that individual grants are required.
- [ ] Browser consumes one centralized effective-access result.
- [ ] Mobile Candidate access operations are fully usable.

## Academic and consequential actions

- [ ] Academic contains Colleges, Departments, Levels, and Sessions & Semesters.
- [ ] Levels are configurable and not limited to 100–400.
- [ ] Referenced academic records prefer deactivation to deletion.
- [ ] Deactivation shows impact and preserves history.
- [ ] No platform-global current-Semester toggle is invented without a new product decision.
- [ ] Any future current-Semester change preserves Course Access and requires confirmation/audit.
- [ ] Consequential mutation APIs have append-only audit before UI enablement.
- [ ] No Activity UI is required.

## Responsive, accessibility, and states

- [ ] Review works well on phone-sized screens.
- [ ] Dense desktop-first pages remain navigable and understandable on mobile.
- [ ] Long Questions, answers, options, and references wrap correctly.
- [ ] All controls are usable by keyboard with visible focus.
- [ ] Question ordering is possible without drag-and-drop.
- [ ] Dialog focus, Escape behavior, and focus return are correct.
- [ ] Status is not communicated by color alone.
- [ ] Loading, empty, no-results, offline, saving, save-failed, expired-session, and error states are present where applicable.
- [ ] Import validation and transaction failures have distinct messages.
- [ ] Raw database errors never reach the Admin UI.
