# Summit University Exam Practice Platform
## ARCHITECTURE.md

This document translates the agreed product plan into a technical system structure.

It does **not** assign work to the three developers yet.

Its purpose is to make sure everybody understands:

- the major systems
- how they connect
- the main data entities
- how access works
- how CBT and written practice differ
- how academic structure is represented
- how content moves from source to publication
- which rules must remain true during implementation

---

# 1. Architectural Goal

The platform should be built as one connected system, not as separate pages that are later forced together.

It must support:

- multiple Colleges
- multiple Departments
- configurable Levels
- multiple Academic Sessions
- First and Second Semester
- courses shared across departments
- CBT or Written exam mode per course offering
- centrally evaluated Course Offering access policies
- manual Admin access grant and revoke in V1
- server-authoritative timed practice
- CBT scoring
- written self-assessment
- content review and publication
- future expansion without major restructuring

The student experience should remain simple even if the internal structure is more detailed.

---

# 2. High-Level System View

```text
STUDENT
  |
  v
AUTHENTICATION
  |
  v
STUDENT PROFILE
  |
  +----------------------+
  |                      |
  v                      v
RELEVANT COURSES      BROWSE ALL COURSES
  |                      |
  +----------+-----------+
             |
             v
        COURSE CATALOGUE
             |
             v
        ACCESS CHECK
             |
             v
   EFFECTIVE-ACCESS RESOLVER
      |             |
    ALLOW          DENY
      |             |
      |             v
      |      ACCESS UNAVAILABLE
      |
      +-------------+
             |
             v
          COURSE
             |
             v
       PRACTICE SETS
             |
      +------+------+
      |             |
      v             v
     CBT          WRITTEN
      |             |
      v             v
   SUBMIT        SUBMIT
      |             |
      v             v
    SCORE         REVIEW
      |             |
      v             v
   REVIEW      SELF-ASSESS
      |             |
      +------+------+
             |
             v
          PROGRESS
```

---

# 3. Main System Domains

The application should be separated logically into these domains:

1. Authentication
2. Student Profile
3. Academic Structure
4. Course Catalogue
5. Course Offerings
6. Practice Content
7. CBT Practice
8. Written Practice
9. Attempts and Answers
10. Results and Progress
11. Access Control
12. Content Contribution
13. Content Review
14. Administration

Payments and bundle commerce are deferred beyond V1. Their eventual design may
create normal Course Access Grants, but payment records must never become a
separate authorization system.

These are system responsibilities, not necessarily separate applications.

---

# 4. Authentication

Authentication handles identity.

It answers:

- Who is this user?
- Is the user logged in?
- What account owns this profile?
- What access grants and Attempts belong to this user?

Authentication should not contain academic logic.

It should not decide:

- which courses the user can browse
- which department the user belongs to
- which courses the user owns

Those responsibilities belong to other domains.

---

# 5. Student Profile

Authentication and academic onboarding are separate flows. V1 supports
email/password authentication; Google OAuth is deferred. An account may exist
before its academic profile is complete. An authenticated user with an
incomplete profile should complete onboarding before entering the main student
experience.

The student profile stores Summit-specific identity and academic information
used for personalisation.

Profile fields:

```text
user_id
full_name
matric_number
department_id
level_id
current_semester_id
```

Email belongs to Supabase Auth and is not duplicated in the profile. College is
derived from Department, and Academic Session is derived from Semester.

The academic profile is complete when full name, matric number, Department,
Level and current Semester are all present. These fields remain nullable so an
authenticated account can exist before onboarding is completed.

The profile is editable. Students may change their full name, Department, Level
and current Semester later.

Important rule:

```text
PROFILE = DISCOVERY / RECOMMENDATION

EFFECTIVE ACCESS POLICY = AUTHORIZATION
```

Changing:

- Full name
- Department
- Level
- Current Semester

must not remove or modify existing Course Access Grants.

Department, Level and current Semester determine recommendation relevance.
College is structural and may support browsing or filtering, but College alone
must not make every Offering in that College recommended.

Profile data does not authorize access and does not determine which Course
Offerings may receive an access grant.

---

# 6. Academic Structure

Core entities:

```text
College
Department
Level
Academic Session
Semester
Course
Course Offering
```

Basic relationship:

```text
College
  |
  +-- Department
        |
        +-- Students

Academic Session
  |
  +-- Semester
        |
        +-- Course Offerings
```

Each Semester belongs to one Academic Session. A Course Offering belongs to a
Semester, so its Academic Session is derived through that relationship rather
than stored again on the Course Offering.

Levels must be configurable data.

Example:

```text
100
200
300
400
500
```

If Summit adds another level later, the system should need new data, not code changes.

---

# 7. Colleges and Departments

A Department belongs to a College.

```text
College
  |
  +-- Department A
  +-- Department B
  +-- Department C
```

Students belong to a Department through their profile.

Courses do not need to belong permanently to only one Department because:

- some courses are general
- some are shared by several departments
- some are department-specific

---

# 8. Courses

A Course is the stable academic identity of a subject across Academic
Sessions.

Example:

```text
course_code: GST 301
course_title: Entrepreneurship
```

A Course should exist once. For example, CSC 301 remains CSC 301 in 2026/2027,
2027/2028 and later sessions.

Do not create:

```text
GST 301 - Software Engineering
GST 301 - Computer Science
GST 301 - Cyber Security
```

if they are the same course.

The relationship between a Course and the students taking it belongs in the
Course Offering audience mappings.

---

# 9. Course Offering

Course Offering is one of the most important entities.

It describes a Course in a particular Semester and, through that Semester, a
particular Academic Session.

```text
Course Offering
  |
  +-- Course
  +-- Semester
  +-- Exam Mode
  +-- Department + Level audience mappings
  +-- Expected Questions per Practice Set
  +-- Practice Duration
```

Example:

```text
Course: GST 301
Session: 2026/2027
Semester: First Semester
Exam Mode: CBT
Audience:
- Software Engineering, 300 Level
- Computer Science, 300 Level
- Cyber Security, 200 Level
```

Level does not belong directly to Course Offering. It belongs to each audience
mapping so the same Course Offering can serve multiple Departments, including
Departments taking the Course at different Levels.

This allows the same Course to be offered differently later. Different Course
Offerings may have different exam modes, audiences, materials, Practice Sets,
questions and teaching emphasis.

Each Course Offering also owns the expected number of Questions in every
Practice Set and the practice duration. Admins configure duration in minutes;
the runtime may represent it in seconds. V1 does not allow individual Practice
Sets to override either value. Course Offering activity remains an independent
operational setting and must not be inferred from whether it has a published
Practice Set.

Example:

```text
2026/2027 -> CBT
2027/2028 -> Written
```

without changing the identity of the Course itself. Offering the Course in a
new Academic Session requires a new Course Offering; it must not overwrite an
older offering because historical content and Attempts remain tied to the
offering they used.

## Phase 3: Course Offering control contract

Phase 3 adds trusted Admin control of an existing Offering's practice
configuration, exam mode, and `is_active` state. It does not change the
Offering's Course or Semester, create Offerings, or manage Course Assignments.
The current schema permits a legacy/unconfigured `NULL`/`NULL` pair for
`expected_questions_per_practice_set` and `practice_duration_seconds`. Initial
configuration supplies both positive integers atomically. Later changes may
replace either or both values atomically, but this Admin API cannot clear them
back to `NULL`. Existing positive-integer schema bounds apply; no smaller limit
is established here. Explicit expected-current inputs compare against the
locked pair with `NULL`-safe semantics. Unchanged requests are rejected without
audit. Initial configuration may omit a reason; subsequent count or duration
changes require a trimmed nonblank reason.

When expected Question count changes, every Practice Set currently in Review
or Published must be fully ready under the proposed configuration. This
includes inactive Sets and pre-existing unrelated readiness defects. Evaluate
all protected Sets through the shared readiness rules and identify every Set
that fails. Draft and Archived Sets do not block. No Question, mapping, status,
or Attempt snapshot changes automatically. A duration-only change does not run
this full protected-Set gate. Duration changes may occur while Sets are
Published and affect new Attempts only; existing duration snapshots, start
times, deadlines, responses, submission state, and finalization stay intact.

A CBT/Written exam-mode change requires no Questions, no Attempts, and no
Review, Published, or Archived Sets for the Offering. Empty Draft Sets are
allowed. A mode change requires an expected-current mode and a trimmed
nonblank reason. It performs no conversion or history rewrite. Existing
exam-mode compatibility triggers remain unchanged as integrity backstops.

Offering activation/deactivation changes only `is_active`. Activation needs
no readiness gate and may omit a reason; deactivation requires a trimmed
nonblank reason. Both require the expected-current activity value and reject
no-ops. Deactivation blocks new Attempts but preserves grants, Set lifecycle,
content, Attempt history, and in-progress Attempt completion under the frozen
deadline. An active Offering may still have unready Sets; the Candidate start
operation continues enforcing its own conditions.

The planned Admin-facing functions are:

```sql
public.admin_update_course_offering_practice_configuration(
  p_course_offering_id uuid,
  p_expected_question_count integer,
  p_expected_duration_seconds integer,
  p_new_question_count integer,
  p_new_duration_seconds integer,
  p_reason text default null
)

public.admin_change_course_offering_exam_mode(
  p_course_offering_id uuid,
  p_expected_exam_mode text,
  p_new_exam_mode text,
  p_reason text
)

public.admin_set_course_offering_activity(
  p_course_offering_id uuid,
  p_expected_is_active boolean,
  p_new_is_active boolean,
  p_reason text default null
)

public.admin_get_course_offering_control_context(p_course_offering_id uuid)

public.admin_preview_course_offering_practice_configuration(
  p_course_offering_id uuid,
  p_new_question_count integer,
  p_new_duration_seconds integer
)
```

Every Admin-facing function must be `SECURITY DEFINER`, set an empty
`search_path`, call `public.assert_admin()`, derive the actor on the server,
grant EXECUTE only to `authenticated`, and grant no browser role direct table
mutation. The context and configuration-preview functions must be genuinely
read-only: they must not finalize Attempts or mutate content, configuration,
lifecycle, grants, policy, audit, or runtime state to compute impact. Unlike an
attempt-aware Candidate detail RPC, they perform no lazy finalization.
Preview has no persistent locks, tokens, tables, mutations, or audit records.
Its result is advisory: the mutation recomputes the decision under locks.

The new internal helper evaluates proposed count/duration using the same rules
as current readiness:

```sql
public.evaluate_practice_set_readiness_with_configuration(
  p_practice_set_id uuid,
  p_expected_questions_per_practice_set integer,
  p_practice_duration_seconds integer
) returns jsonb
```

It is not directly executable by browser roles.
`public.evaluate_practice_set_readiness(uuid)` remains the authoritative
current-configuration wrapper with identical behavior and grants. Preview and
mutation share that implementation rather than duplicating readiness rules.

Each Phase 3 Offering-control mutation uses one database transaction and relies
on PostgreSQL `READ COMMITTED` semantics. After Admin assertion, it validates
inputs and the transaction-isolation context before acquiring mutation locks.
Only `READ COMMITTED` is supported: an unsupported isolation context must be
rejected with deliberate SQLSTATE `0A000` (`feature_not_supported`) and the
message `Phase 3 Offering control requires READ COMMITTED transaction isolation`.
This rejection occurs before any consequential mutation and creates no audit
event. The implementation must not silently assume equivalent behavior under
`REPEATABLE READ` or `SERIALIZABLE`.

After validation, the mutation locks the Offering `FOR UPDATE` and verifies
expected values.
Count and mode changes then lock **all** child Practice Sets in ID order with
`FOR UPDATE NOWAIT`, including Draft Sets. A lock conflict aborts with retryable
SQLSTATE `40001`; `SKIP LOCKED` is forbidden. After all required locks are
acquired, subsequent SQL statements inspect statuses, impact, and proposed
readiness or mode restrictions using fresh statement snapshots under
`READ COMMITTED`. The RPC then uses a defensive `UPDATE` with expected-value
predicates and `RETURNING`, requires exactly one updated row, and records the
audit event before commit. Duration-only and
activity-only changes require the Offering lock but not child Set locks.
Offering deactivation serializes with the existing Attempt-start path, which
locks the Offering. Future content-authoring RPCs must join a compatible
Offering/Practice-Set locking protocol.

Successful changes create exactly one append-only audit event through
`public.record_admin_audit_event(...)` in the mutation transaction. The target
type is `course_offering` and the target ID is its UUID. Action names are
`course_offering.configuration_updated`,
`course_offering.exam_mode_changed`, and
`course_offering.activity_changed`. Concise metadata includes previous/new
values and the relevant protected-Set or activity impact summary, without
Question payloads. Validation failure, stale expected state, lock conflict,
readiness/mode rejection, and no-op create no event; an audit failure rolls
back the Offering change. Required reasons follow the operation rules above.

Course Assignment mutation, Question/Source authoring, manual Course Access
mutation, payments, Admin/Candidate UI, platform policy mutation, and legacy
`NULL`-configuration removal/backfill are separate work. Assignment-free
general browse/search and archived in-progress Attempt discoverability are
known separate Candidate discovery issues. Phase 3 does not change Candidate
runtime or discovery functions.

---

# 10. Departments Attached to a Course Offering

A Course Offering may apply to zero or many Departments.

A clean model is an explicit relationship:

```text
course_offering_departments

course_offering_id
department_id
level_id
```

The combination of Course Offering, Department and Level defines an audience
entry. This avoids duplicating Courses or Course Offerings while allowing one
offering to serve different Departments at different Levels.

---

# 11. Course Discovery

Course discovery should be College-first.

```text
Browse Courses
  |
  +-- College A
  |     |
  |     +-- All Courses
  |     +-- Filter by Department
  |
  +-- College B
        |
        +-- All Courses
        +-- Filter by Department
```

Students should also be able to search by:

- course code
- course title

A student's Department, Level and current Semester determine recommendation
relevance through the Offering's academic assignments. College is structural
browsing/filter context and must not independently recommend every Offering in
the College.

It must not restrict the wider catalogue.

College-first discovery is derived through the Colleges of Departments attached
to Course Offerings. A Course itself does not permanently belong to a College
or Department.

Candidate catalogue/discovery is conceptually a read surface, but its trusted
RPCs are not uniformly read-only. The current attempt-aware Course Offering
detail path may lazily finalize an expired Attempt as narrowly scoped trusted
server-side runtime behavior. This grants no Candidate direct table-mutation
privileges. Phase 3 Admin context and preview RPCs must remain genuinely
read-only, as specified in the Offering-control contract above.

The product rule makes Browse All independent of profile matching; the current
assignment-free browse/search discrepancy remains a separate issue. Course
details may expose safe metadata for active, published Practice Sets: title,
position, derived Question count, and an existing in-progress Attempt identifier.
Discovery/detail RPCs never create Attempts and never expose Question or
protected review content; actual Question delivery remains behind the trusted
Practice runtime.

---

# 12. Recommended Courses vs Accessible Courses

These are separate concepts.

```text
RECOMMENDED COURSES
Based on Department + Level + current Semester assignments

ACCESSIBLE COURSES
Based on the centralized effective-access decision
```

The dashboard can show:

```text
YOUR COURSES
Course Offerings the Candidate can currently access

RELEVANT COURSES
Active offerings matching profile Department + Level + current Semester

BROWSE ALL COURSES
Open catalogue, unrestricted by profile
```

A course can be relevant without effective access. Academic assignment determines
relevance, not authorization.

A Candidate may access an Offering outside their current academic profile. Profile
changes never remove an existing Course Access Grant; the grant remains effective
until it expires or is revoked.

Your Courses and Relevant Courses are intentionally separate dashboard lists.
Relevant Courses exclude offerings already in Your Courses and do not confer
authorization. A Course detail may still report an existing in-progress Attempt
after effective access ends so the Candidate can Continue it; only an explicit
Start command can create a new Attempt, and that command requires a positive
server-side effective-access decision.

---

# 13. Exam Mode

Initial supported modes:

```text
CBT
WRITTEN
```

Exam mode belongs to Course Offering.

Not permanently to Course.

Possible values:

```text
cbt
written
```

The system should not assume every course has both.

---

# 14. Practice Sets

A Practice Set belongs to one Course Offering. It does not store a separate
exam mode; behaviour is derived from the Course Offering.

```text
Course
  |
  v
Course Offering
  |
  v
Practice Sets
  |
  +-- Set 1
  +-- Set 2
  +-- Set 3
```

A Practice Set should know:

```text
id
course_offering_id
title
position
status
```

Question count is derived from Practice Set membership rather than stored as
mutable duplicated state.

The Practice Set is the only content publication unit. Its complete lifecycle is:

```text
draft
review
published
archived
```

Questions belong to Course Offerings and may be reused across multiple Practice
Sets within the same Course Offering. Membership is an explicit ordered mapping
that prevents a Practice Set from containing a Question from another offering.

Questions do not have an independent editorial or publication lifecycle.
Question eligibility is derived from data integrity, `is_active`, exam-mode
requirements and the Question's valid relationship to the Practice Set. The
`is_active` field remains an operational kill switch.

Moving a Practice Set from Draft to Review requires structural completeness:
the exact Offering-configured Question count, valid and ordered mappings,
same-Offering integrity, operationally active Questions, and all required CBT
or Written answer data. Publishing requires the Practice Set to be in Review
and the same readiness check to still pass. Readiness is derived; it is not an
Approved or ready lifecycle state.

A Candidate may start new practice only when the Course Offering is active, the
Practice Set is active and published, the Candidate has effective access,
and readiness/integrity still passes. These conditions are enforced by trusted
server logic, not inferred from frontend visibility.

Direct Candidate access to protected practice-content tables remains denied;
Candidates already receive authorized content through trusted runtime RPCs.
Pre-submit RPCs expose only safe, frozen Attempt content. Protected answer and
review material remains governed by submission and runtime rules, and Attempt
snapshots remain the historical truth. Restricted direct table access does not
mean that Candidates have no content access, nor does RPC access authorize
direct `SELECT` on protected content tables.

---

# 15. Questions

Questions belong directly to Course Offerings, not permanently to a single
Practice Set. The base Question contains student-visible prompt content and an
operational active state. It does not carry an editorial or publication
lifecycle.

Shared question information may include:

```text
id
course_offering_id
question_text
is_active
```

Exam mode is derived from the Course Offering. Options, correct answers, model
answers, key points, explanations and references remain outside the base table
so protected review content is separate from student-visible prompts.

---

# 16. CBT Question Structure

Student-visible CBT options are ordered child records of a Question. The UI may
derive labels such as A/B/C/D from position, and the schema does not require
exactly four options.

```text
question_text
options
```

The correct option is stored separately in a protected answer-key table, with a
database constraint ensuring that it belongs to the same Question. Explanation
and reference content is also stored separately as protected review content.

Correct answers and review content must not be exposed while an Attempt is
active.

---

# 17. Written Question Structure

Written Questions keep student-visible prompt content in the base Question
table. Model answers and ordered key points are stored separately as protected
answer content, while explanations and references use the shared protected
review-content record.

```text
question_text
model_answer
key_points
reference_note
```

A student may:

- type an answer
- skip

Model answers, key points and review content must remain hidden until the
Practice Set is submitted.

---

# 18. Practice Attempt

An explicit Candidate Start command creates a durable Attempt immediately.
Starting the same Practice Set while that Candidate has an in-progress Attempt
resumes it; at most one such Attempt may exist per Candidate and Practice Set.
After submission, another explicit Start creates a new retry Attempt.

```text
Attempt
  |
  +-- Candidate
  +-- Course Offering
  +-- Practice Set
  +-- Exam Mode Snapshot
  +-- Duration Snapshot
  +-- Authoritative Deadline
  +-- Status
  +-- Started At
  +-- Submitted At
```

Initial status values:

```text
in_progress
submitted
```

At Attempt creation, the server validates the complete published Practice Set
and copies its curated Question and option order plus the relevant prompt,
answer-key, explanation/reference, model-answer and key-point content into
snapshot tables. Later edits to live content do not rewrite what the Candidate
received.

A new Attempt snapshots the Course Offering's practice duration and an
authoritative deadline calculated from the database clock. Existing Attempts
created before timed practice must not receive invented deadlines. The server
enforces the deadline on reads and mutations; the browser countdown is
presentation only and cannot extend an Attempt by refreshing or changing local
state.

Start is a command; read/resume is a query and must never create an Attempt.
Effective access is required only to create a new Attempt. Ownership and Attempt
state allow an already-started Attempt to be resumed, saved, submitted and
reviewed after effective access ends, subject to the Attempt's own authoritative
deadline. In particular, an Attempt validly started before a `free_until` cutoff
may finish after that cutoff.

Candidate answers are persisted server-side through trusted functions. Browser
storage may later provide a safe responsive cache, but is not authorization or
historical truth and must not contain protected pre-submission review data.

---

# 19. Attempt Answers

Candidate responses are stored separately from the frozen Attempt content.

```text
CBT
- response references a frozen Attempt option
- missing response means unanswered

WRITTEN
- Candidate supplies non-blank response text
- or explicitly marks the Question skipped
```

---

# 20. CBT Submission

```text
Attempt
  |
  v
Freeze Answers
  |
  v
Compare with Correct Answers
  |
  v
Calculate Score
  |
  v
Save Result
  |
  v
Unlock Review
```

After submission, the student's submitted answers should not silently change.

The result comes from the frozen submitted state and is stored separately with
correct count, total Questions and percentage. It is not recalculated from live
content later.

The server scores the complete frozen Question set: an unanswered CBT Question
is incorrect, and protected answers and review content become readable only
after submission.

---

# 21. Written Submission

```text
Attempt
  |
  v
Freeze Answers / Skips
  |
  v
Unlock Review
  |
  v
Student compares answers
  |
  v
Student self-assesses
```

Written review uses the frozen model answer, key points and review content. The
system does not automatically decide whether the written response is correct in
V1.

Written submission requires every frozen Question to be either answered or
explicitly skipped. Responses become immutable on submission; protected review
content is then released and self-assessment may be saved or updated.

When time expires, the server submits the Attempt using the responses already
persisted. Any unresolved Written Questions remain timed-out/unanswered; the
system must not convert them into Candidate-selected skips.

---

# 22. Written Self-Assessment

Possible values:

```text
Got it              (got_it)
Partially got it    (partially_got_it)
Did not get it      (did_not_get_it)
```

Exact labels can change later.

Conceptually:

```text
Written Answer
  |
  +-- Student Response
  +-- Model Answer
  +-- Key Points
  +-- Self Assessment
```

---

# 23. Progress

Progress should be derived from Attempts where possible.

CBT progress may include:

```text
sets attempted
latest score
best score
average score
attempt history
```

Written progress may include:

```text
sets attempted
questions answered
questions skipped
got_it count
partially_got_it count
did_not_get_it count
```

Avoid unnecessary duplicate counters that can become inconsistent.

---

# 24. Payments

Payments are deferred beyond V1. Manual Admin Course Access grant/revoke remains
part of V1, with reasons, integrity checks and append-only audit records. The
platform access policy may also make an Offering accessible without an individual
grant in `free` or active `free_until` mode.

When commerce is introduced later, payment remains separate from academic
profile and must not become the authorization source of truth.

```text
Payment
  |
  +-- User
  +-- Amount
  +-- Status
  +-- Provider Reference
  +-- Created At
```

Possible status values:

```text
pending
successful
failed
abandoned
```

When grants are required, they may be produced by a trusted manual Admin operation
in V1 and later by verified individual purchase, academic bundle purchase or a
future institutional grant. Payment itself never authorizes access.

---

# 25. Future Purchase Structure

Future commerce must support both an individual Course Offering purchase and an
academic bundle/package purchase. Buying an individual Offering must not require
first buying the Candidate's Department/Level package, and Candidates may buy
Offerings outside their current academic profile.

```text
Purchase
  |
  +-- Payment
  +-- User
  +-- Duration
  |
  +-- Purchase Items
        |
        +-- Individual Course Offering
        +-- or Academic Bundle snapshot
              |
              +-- Explicit Course Offering items
```

One purchase therefore does not imply exactly one Course Offering. Trusted
processing of an academic bundle purchase produces Course Access Grants for
every included Course Offering. Those grants become the authorization primitive
whenever the platform is in `grant_required` mode or a `free_until` cutoff has
been reached.

---

# 26. Future Purchase Duration

Initial duration choices:

```text
1 month
2 months
3 months
```

Duration should be stored as actual access dates.

Example:

```text
access_start: 2026-10-05
access_end:   2026-12-05
```

Do not calculate access from the student's current profile.

---

# 27. Course Access

The server must evaluate effective Course Offering access centrally. The platform
access policy supports three modes:

```text
free           -> no individual Course Access Grant required
free_until     -> before cutoff no grant required; at/after cutoff an active grant is required
grant_required -> an active effective Course Access Grant is required
```

When grants are required, including at or after a `free_until` cutoff, Course
Access Grants are the authorization primitive for a specific Course Offering.
They do not target the stable Course record.

```text
Course Access Grant
  |
  +-- Candidate
  +-- Course Offering
  +-- Starts At
  +-- Expires At
  +-- Source
  +-- Optional Revocation
```

Multiple historical grants may exist for the same Candidate and Course
Offering. A Candidate has active access when any matching grant has started,
has not expired and has not been revoked.

```text
starts_at <= now()
AND expires_at > now()
AND revoked_at IS NULL
```

A Candidate may receive access to any Course Offering regardless of their
current Department, Level, Semester or other profile fields. Academic profile
data controls relevance and discovery, not authorization, so profile changes
must not alter or remove existing grants.

Manual Admin grant/revoke is part of V1. Admin operations must support access
inspection, required reasons, appropriate idempotency and append-only audit.
Verified individual payment, academic bundle purchase, manual Admin action and a
future institutional process may produce Course Access Grants. The payment or
package record itself is never authorization.

---

# 28. Access Check

Before starting new practice, trusted server logic resolves effective access:

```text
User
  |
  v
Course Offering
  |
  v
Resolve Effective Access
  |
  +-- free -> Allow via platform_free
  |
  +-- free_until and before cutoff -> Allow via free_period
  |
  +-- free_until at/after cutoff and active grant -> Allow via course_access_grant
  |
  +-- grant_required and active grant -> Allow via course_access_grant
  |
  +-- Otherwise -> Show access unavailable
```

This must be enforced on the backend/database level. The browser consumes the
authoritative result; it must not independently combine policy mode, cutoff and
grant state. Reaching a `free_until` cutoff ends grant-free starts but does not
change the stored policy mode: a Candidate with an active Course Access Grant may
still start. No scheduler, Admin action or database mutation is required at the
cutoff. An Attempt validly started before it remains governed by its snapshotted
authoritative deadline.

Hiding a button in the frontend is not access control.

---

# 29. Future Bundles

Academic bundle/package commerce is deferred beyond V1. A bundle is scoped by:

- Department
- Level
- Academic Session
- Semester

Its composition is an explicit list of Course Offerings. Academic assignments may
suggest or populate that list, but they are not live bundle membership: later
assignment changes must not silently rewrite an existing bundle or the contents
captured by an existing purchase.

```text
Candidate chooses an individual Offering or academic bundle
        |
        v
Pricing Logic
        |
        +-- Base Price
        +-- Duration
        +-- Bundle Discount
        |
        v
Final Amount
```

After trusted successful purchase processing, normal Course Access Grants are
created for each purchased Course Offering. Payment and bundle records do not
replace effective-access evaluation; those grants authorize starts when the
platform is in `grant_required` mode or a `free_until` cutoff has been reached.

---

# 30. Content Source

A Content Source records where academic material came from and belongs to a
specific Course Offering.

Possible source types:

```text
lecturer_pdf
lecture_material
student_jotting
past_question
lecture_question
manual
other
```

Possible information:

```text
source_type
course_offering_id
title
description
storage_path
created_at
```

Questions and Sources use an explicit many-to-many provenance relationship.
Each relationship is constrained to one Course Offering, allowing a Question to
retain multiple supporting Sources without crossing academic periods.

Not every source has to be exposed directly to students, but the platform should retain it internally where possible.

---

# 31. Future Content Contribution

Contributor workflows are deferred beyond V1. If introduced later,
contributors should not need full Admin access.

They may submit:

- material
- past questions
- corrections
- course updates
- source information

```text
Contributor
  |
  v
Submission
  |
  v
Pending Review
```

Submission is not publication.

---

# 32. Content Review

```text
Course
  -> Course Offering
      -> Practice Set (draft)
          -> Add Questions manually or import them in bulk
          -> Validate structural completeness
          -> Practice Set (review)
          -> Revalidate readiness
          -> Practice Set (published)
          -> Practice Set (archived)
```

The Practice Set lifecycle is exactly:

```text
draft
review
published
archived
```

There is no Approved Practice Set state. Questions do not have a parallel
editorial/publication lifecycle. Readiness is a derived result used to gate
Review and Publish.

V1 Admin authoring is Practice Set-first rather than Question Pool-first.
Questions remain reusable entities underneath, but the primary workflow does
not require an Admin to manage a global Question library before building a Set.

Bulk Question Import is V1 and runs inside a Practice Set:

```text
upload -> parse -> validate -> preview -> confirm -> atomic commit
```

The final commit creates Questions and ordered Practice Set mappings in one
transaction. A failure must not leave a partial import.

Frozen Attempt snapshots protect historical Attempts from later live-content
changes. For future Attempts, a substantive correction to a Question reused by
published Practice Sets must not silently alter every Set that maps it. V1 uses
impact-aware replacement and explicit remapping for selected Sets; harmless
typo, formatting or reference corrections may be audited in place. There is no
formal Question-version or Practice-Set-version subsystem in V1.

---

# 33. Future Content Operations Roles

A dedicated Content Manager role is not part of V1. V1 roles remain Candidate
and Admin. The architecture may allow a narrower content role later without
introducing a permission matrix before there is a demonstrated need.

Possible responsibilities:

- review submissions
- manage courses
- manage Course Offerings
- create/edit Practice Sets
- review Practice Set content
- publish a reviewed Practice Set whose readiness check passes
- handle reported errors
- track source information

Any future content role must remain separate from Candidate access.

---

# 34. Administration

Admin may manage:

```text
Academic Structure
- Colleges
- Departments
- Levels
- Sessions
- Semesters

Courses
- Courses
- Course Offerings
- Exam Modes

Content
- Practice Sets
- Questions
- Sources
- Reviews

Users
- Student profiles
- Access

Operations
- Contributors
- Reports
```

V1 Admin operations must be server-authorized from explicit Admin membership.
Frontend visibility is not authorization.

---

# 35. Roles

Candidate is the normal role for an authenticated user and does not require an
editable role field in the profile. Admin authority is assigned explicitly
through `app_admins`, separate from profiles and Candidate academic data.

Admin membership and Candidate Course Access are independent. Admin status does
not automatically grant access to Course Offerings; later policies may combine
the two checks explicitly where required.

V1 has exactly two roles: Candidate and Admin. A Content Manager role and a
detailed permission matrix are deferred.

---

# 36. Security Boundaries

A student may:

- read published course content they have access to
- create their own Attempts
- read their own Attempts
- update their own profile

A student must not:

- read another student's Attempt
- modify correct CBT answers
- change model answers
- grant themselves access
- publish or archive Practice Sets
- bypass Practice Set readiness

A contributor may submit content in a future contribution workflow but should
not automatically publish a Practice Set.

---

# 37. Database Security

If Supabase is used, Row Level Security should be part of the architecture from the beginning.

Examples:

```text
profiles
- user can read/update own profile

attempts
- user can read/create own attempts

attempt_answers
- user can read/write answers belonging to own active attempt

course_access
- user can read own access
- user cannot grant or revoke access directly

questions
- students receive Questions only through an eligible published Practice Set
```

Correct answers and model answers must not be exposed carelessly during active Attempts.

The initial Practice Content tables have RLS enabled with no normal-user grants
or policies. They remain inaccessible to normal users until later access and
Attempt policies deliberately expose the appropriate student-visible content.

---

# 38. Trusted Server-Side Actions

Some actions must happen through trusted backend logic.

Examples:

```text
inspect Candidate and Offering access
grant or revoke manual Course Access
calculate CBT result
publish a reviewed Practice Set whose readiness check passes
grant administrative access
change privileged roles
```

Frontend code should not be trusted to perform these directly.

Append-only Admin audit data must exist before consequential Admin mutation
APIs. At minimum this covers Practice Set transitions, access grant/revoke,
academic and Offering configuration changes, substantive published-content
corrections/replacements, and Admin membership changes. V1 does not require an
Activity UI.

---

# 39. Conceptual Route Structure

```text
/
  landing

/auth
  /login
  /signup

/onboarding

/dashboard

/courses
  /browse
  /:courseOfferingId

/practice
  /:practiceSetId

/attempts
  /:attemptId
  /:attemptId/review

/profile

/admin
  /academic
  /courses
  /content
  /users
  /candidates

/content
  /submissions
```

Exact frontend routing can change.

The important point is that routes should reflect system responsibilities.

---

# 40. Recommended Frontend Boundaries

Organise frontend code by feature/domain rather than random page ownership.

Example:

```text
src/
  features/
    auth/
    profile/
    academics/
    courses/
    practice/
    attempts/
    progress/
    access/
    content/
    admin/
```

This will make team ownership easier later and reduce scattered feature logic.

---

# 41. Shared Practice Engine Principle

CBT and Written should share the same outer flow where practical.

Shared concepts:

```text
Practice Set
Attempt
Question Navigation
Submission
Review
Progress
```

Different answer handling:

```text
CBT
- selected option
- automatic scoring

WRITTEN
- typed answer / skip
- self-assessment
```

Reuse shared behaviour without forcing both modes into exactly the same implementation.

---

# 42. State Transitions

Important entities should have clear states.

Attempt:

```text
in_progress
    |
    v
submitted
```

Practice Set:

```text
draft
  |
  v
review
  |
  v
published
  |
  v
archived
```

Clear transitions reduce inconsistent states.

---

# 43. Important Invariants

## Academic

- A Course is the stable academic identity across Academic Sessions.
- A Course Offering is that Course in one Semester and its parent Academic Session.
- One Course should not be duplicated for every Department.
- Levels must be configurable.
- Level does not belong directly to Course Offering.
- Course Offering audience is defined by Department + Level mappings.
- Older Course Offerings must be preserved for historical content and Attempts.
- Exam mode belongs to Course Offering.
- Expected Questions per Practice Set and practice duration belong to Course Offering.

## Access

- A Candidate may be granted access to any available Course Offering.
- Student profile does not restrict access eligibility.
- Profile changes do not modify existing access.
- Effective access is centrally evaluated as platform `free`, a `free_until`
  window before cutoff, or an active Course Access Grant when the policy is
  `grant_required` or `free_until` has reached its cutoff.
- Payment is never authorization.

## Practice

- Active CBT Attempts do not expose correct answers.
- Active Written Attempts do not expose model answers.
- Submitted Attempts are frozen.
- New Attempts snapshot duration and a server-authoritative deadline.
- Existing pre-timer Attempts do not receive invented deadlines.
- CBT scores come from submitted answers.
- Written evaluation is self-assessed in V1.
- Written timeout leaves unresolved Questions timed-out/unanswered, not skipped.

## Content

- Practice Set is the only content publication lifecycle.
- Questions have derived eligibility and retain `is_active` as a kill switch.
- Contributor submission is not automatic publication.
- Source/provenance should be retained where possible.

---

# 44. Conceptual Entity Map

```text
USER
 |
 +-- PROFILE
 |
 +-- COURSE ACCESS GRANTS
 |
 +-- ATTEMPTS
       |
       +-- ATTEMPT ANSWERS
       |
       +-- WRITTEN SELF-ASSESSMENT


COLLEGE
 |
 +-- DEPARTMENTS


ACADEMIC SESSION
 |
 +-- SEMESTER


COURSE
 |
 +-- COURSE OFFERING
       |
       +-- SEMESTER
       |     |
       |     +-- ACADEMIC SESSION
       |
       +-- OFFERING DEPARTMENT + LEVEL AUDIENCES
       |
       +-- EXPECTED QUESTIONS + PRACTICE DURATION
       |
       +-- PRACTICE SETS
               |
               +-- ORDERED QUESTION MAPPINGS
                       |
                       +-- QUESTIONS
                       |
                       +-- SOURCE


CONTENT SUBMISSION
 |
 +-- CONTRIBUTOR
 |
 +-- REVIEW
 |
 +-- PRACTICE SET AUTHORING


PLATFORM ACCESS POLICY
 |
 +-- free / free_until / grant_required


ACADEMIC BUNDLE (FUTURE)
 |
 +-- DEPARTMENT + LEVEL + ACADEMIC SESSION + SEMESTER
 |
 +-- EXPLICIT COURSE OFFERING ITEMS
 |
 +-- PURCHASE SNAPSHOT -> COURSE ACCESS GRANTS
```

---

# 45. Suggested Core Tables

This is conceptual, not final SQL.

```text
profiles

colleges
departments
levels
academic_sessions
semesters

courses
course_offerings
course_offering_departments

practice_sets
questions
practice_set_questions
question_key_points
content_sources

attempts
attempt_answers
written_self_assessments

course_access_grants
access_policy_configuration
admin_audit

future commerce concepts:
academic_bundles
academic_bundle_items
purchases
purchase_items

content_submissions
content_reviews
app_admins
```

Columns and constraints should be finalised during schema design.

---

# 46. What Should Not Be Hardcoded

Avoid hardcoding:

- 100 to 400 Level only
- one fixed academic session
- one fixed semester
- departments in frontend source code
- course lists in frontend source code
- exam mode permanently on Course
- access based on current profile
- bundle prices in many components
- correct answers in client-only logic
- admin permissions based only on frontend visibility

These should come from controlled data or trusted backend logic.

---

# 47. V1 Technical Boundary

V1 needs enough architecture for:

```text
Auth
Profile
Academic Structure
Course Catalogue
Course Offerings
Effective Access Policy
Course Access Grants
Practice Sets
CBT Attempts
Written Attempts
Submission
Review
Self-Assessment
Progress
Admin Content Management
Basic Content Review
Manual Course Access Administration
Admin Audit
```

It does not need to solve:

```text
AI written grading
social features
leaderboards
advanced analytics
lecturer portals
multi-university architecture
complex contributor payouts
recommendation AI
```

---

# 48. Implementation Principle

Build vertically.

A weak early milestone is:

```text
Build all login pages
Build all dashboards
Build all admin pages
```

A stronger early milestone is:

```text
One student
  |
  v
One valid profile
  |
  v
One Course Offering
  |
  v
One positive effective-access decision
  |
  v
One Practice Set
  |
  v
One completed Attempt
  |
  v
One Review
  |
  v
Progress saved
```

Once that full path works, expand safely.

---

# 49. Architecture Summary

Keep these concepts separate:

```text
COURSE
is the stable academic identity across Academic Sessions

COURSE OFFERING
is that Course in a specific Semester and its parent Academic Session

COURSE OFFERING DEPARTMENT
defines a Department + Level audience for the Course Offering

PROFILE
recommends Offerings from Department + Level + current Semester assignments

COURSE ACCESS
is resolved centrally from free policy, the pre-cutoff free window, or an active
grant under grant-required or post-cutoff free-until policy

PRACTICE SET
contains the questions

ATTEMPT
records a student's practice session

CONTENT SOURCE
records where questions/material came from

CONTENT REVIEW
decides what is safe to publish
```

If these concepts remain separate, the platform can grow without becoming difficult to maintain.

---

# 50. Next Document

After the architecture is agreed, the next document should be:

```text
DEVELOPMENT_WORKFLOW.md
```

That document should define:

- how the three developers work in one repository
- how branches are used
- how features are divided
- how architecture changes are agreed
- how shared contracts are handled
- how AI-assisted development fits into the workflow
- how code review happens
- how database changes are coordinated
- how integration is handled
- how to avoid duplicate or conflicting implementations
