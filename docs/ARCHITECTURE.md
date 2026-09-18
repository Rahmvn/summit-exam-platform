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
- unrestricted course purchasing
- course-based timed access
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
      +------+------+
      |             |
   HAS ACCESS     NO ACCESS
      |             |
      |             v
      |         PAYMENT
      |             |
      |             v
      |        ACCESS RECORD
      |             |
      +------+------+
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
11. Payments
12. Access Control
13. Content Contribution
14. Content Review
15. Administration

These are system responsibilities, not necessarily separate applications.

---

# 4. Authentication

Authentication handles identity.

It answers:

- Who is this user?
- Is the user logged in?
- What account owns this profile?
- What purchases and attempts belong to this user?

Authentication should not contain academic logic.

It should not decide:

- which courses the user can browse
- which department the user belongs to
- which courses the user owns

Those responsibilities belong to other domains.

---

# 5. Student Profile

The student profile stores academic information used for personalisation.

Possible fields:

```text
user_id
college_id
department_id
level_id
current_academic_session_id
current_semester_id
```

The profile is editable.

Important rule:

```text
PROFILE = DISCOVERY / RECOMMENDATION

PURCHASED ACCESS = ACTUAL ACCESS
```

Changing:

- College
- Department
- Level
- Academic Session
- Semester

must not remove or modify access to courses already purchased.

The profile helps determine what to show first.

It does not determine what the student is allowed to buy.

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

A Course represents the academic subject itself.

Example:

```text
course_code: GST 301
course_title: Entrepreneurship
```

A Course should exist once.

Do not create:

```text
GST 301 - Software Engineering
GST 301 - Computer Science
GST 301 - Cyber Security
```

if they are the same course.

The relationship between a Course and the students taking it belongs in Course Offering.

---

# 9. Course Offering

Course Offering is one of the most important entities.

It describes a Course being offered during a particular academic period.

```text
Course Offering
  |
  +-- Course
  +-- Academic Session
  +-- Semester
  +-- Level
  +-- Exam Mode
  +-- Departments taking it
```

Example:

```text
Course: GST 301
Session: 2026/2027
Semester: First Semester
Level: 300
Exam Mode: CBT
Departments:
- Software Engineering
- Computer Science
- Cyber Security
```

This allows the same Course to be offered differently later.

Example:

```text
2026/2027 -> CBT
2027/2028 -> Written
```

without changing the identity of the Course itself.

---

# 10. Departments Attached to a Course Offering

A Course Offering may apply to one or many Departments.

A clean model is an explicit relationship:

```text
course_offering_departments

course_offering_id
department_id
```

This avoids duplicating Courses or Course Offerings.

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

A student's profile may affect ordering or recommendations.

It must not restrict the wider catalogue.

---

# 12. Recommended Courses vs Purchased Courses

These are separate concepts.

```text
RECOMMENDED COURSES
Based on profile and current academic period

PURCHASED COURSES
Based on active access records
```

The dashboard can show:

```text
YOUR COURSES
Courses currently unlocked

RELEVANT COURSES
Suggested from profile

BROWSE ALL COURSES
Open catalogue
```

A course can be relevant without being purchased.

A purchased course remains accessible even after profile changes, until its access expires.

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

A Course Offering contains Practice Sets.

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
question_count
```

Possible status values:

```text
draft
review
published
archived
```

Students should only see published content.

---

# 15. Questions

Questions need to support both CBT and Written practice.

Shared question information may include:

```text
id
question_text
question_type
explanation
reference_note
source_id
difficulty
status
```

Initial question types:

```text
objective
written
```

The exact database implementation can use either:

- one question table with type-specific fields
- or a shared question table plus type-specific detail tables

The architecture should avoid duplicating the whole practice system unnecessarily.

---

# 16. CBT Question Structure

A CBT question needs:

```text
question_text
option_a
option_b
option_c
option_d
correct_option
explanation
reference_note
```

Correct answers must not be exposed while the attempt is active.

They are used only after submission or by trusted admin/content processes.

---

# 17. Written Question Structure

A Written question needs:

```text
question_text
model_answer
key_points
reference_note
```

A student may:

- type an answer
- skip

The model answer must remain hidden until the Practice Set is submitted.

Key points can be stored as a list.

---

# 18. Practice Attempt

Every time a student starts a Practice Set, the system creates an Attempt.

```text
Attempt
  |
  +-- Student
  +-- Practice Set
  +-- Status
  +-- Started At
  +-- Submitted At
  +-- Score if CBT
```

Initial status values:

```text
in_progress
submitted
```

Other states can be added later if needed.

---

# 19. Attempt Answers

Answers should be stored separately from the Attempt.

```text
Attempt
  |
  +-- Answer 1
  +-- Answer 2
  +-- Answer 3
```

A shared structure can include:

```text
attempt_id
question_id
answer_type
selected_option
written_answer
is_skipped
```

CBT example:

```text
selected_option = B
written_answer = null
```

Written example:

```text
selected_option = null
written_answer = "..."
```

Skipped Written example:

```text
written_answer = null
is_skipped = true
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

The result must come from the frozen submitted state.

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

The system does not automatically decide whether the written answer is correct in V1.

---

# 22. Written Self-Assessment

Possible values:

```text
got_it
partially_got_it
did_not_get_it
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

Payment is separate from academic profile.

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

Access should only be granted from a verified successful payment or a trusted administrative grant.

---

# 25. Purchase Structure

A student may purchase one or several Course Offerings.

```text
Purchase
  |
  +-- Payment
  +-- User
  +-- Duration
  |
  +-- Purchase Items
        |
        +-- Course Offering A
        +-- Course Offering B
        +-- Course Offering C
```

This supports bundles without tying the architecture to one fixed bundle definition.

---

# 26. Access Duration

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

Course Access is the source of truth for unlocking paid content.

```text
Course Access
  |
  +-- User
  +-- Course Offering
  +-- Access Start
  +-- Access End
  +-- Source
```

Possible sources:

```text
purchase
admin_grant
promotion
```

Important:

```text
USER CHANGES DEPARTMENT
        |
        v
COURSE ACCESS REMAINS UNCHANGED
```

Profile changes must not revoke access.

---

# 28. Access Check

Before opening paid content:

```text
User
  |
  v
Course Offering
  |
  v
Check Active Access
  |
  +-- Active -> Allow
  |
  +-- Missing/Expired -> Show Purchase
```

This must be enforced on the backend/database level.

Hiding a button in the frontend is not access control.

---

# 29. Bundles

Bundle pricing is a commerce rule.

It should not alter Course or Course Offering structure.

```text
Student selects courses
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

After successful payment, normal Course Access records are created for each purchased Course Offering.

---

# 30. Content Source

A Content Source records where academic material came from.

Possible source types:

```text
lecturer_pdf
lecture_material
student_jotting
past_question
lecture_question
manual
ai_generated
other
```

Possible information:

```text
source_type
course_offering_id
description
file_reference
submitted_by
created_at
```

Not every source has to be exposed directly to students, but the platform should retain it internally where possible.

---

# 31. Content Contribution

Contributors should not need full admin access.

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
SOURCE / SUBMISSION
        |
        v
CONTENT REVIEW
        |
        +-- Reject
        |
        +-- Request Correction
        |
        +-- Approve
                |
                v
         QUESTION PREPARATION
                |
                v
         ANSWER VERIFICATION
                |
                v
             PUBLISH
```

Possible statuses:

```text
draft
submitted
under_review
changes_requested
approved
published
rejected
archived
```

The system does not need every status on day one, but it should not assume content goes directly from creation to publication.

---

# 33. Content Manager

A Content Manager should have controlled permissions.

Possible responsibilities:

- review submissions
- manage courses
- manage Course Offerings
- create/edit Practice Sets
- review questions
- approve publication
- handle reported errors
- track source information

This role should be separate from normal student access.

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
- Payments

Operations
- Contributors
- Content managers
- Reports
```

Permissions should be role-based.

---

# 35. Roles

Possible initial roles:

```text
student
contributor
content_manager
admin
```

A user may hold more than one role later.

Do not make every non-student a full admin.

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
- change payment status
- publish questions

A contributor may submit content but should not automatically publish it.

A Content Manager may manage content without unrestricted platform administration.

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
- user cannot create paid access directly

payments
- user can read own payments
- payment verification is server-side

questions
- students receive only appropriate published practice content
```

Correct answers and model answers must not be exposed carelessly during active Attempts.

---

# 38. Trusted Server-Side Actions

Some actions must happen through trusted backend logic.

Examples:

```text
verify payment
grant purchased access
calculate CBT result
publish reviewed content
grant administrative access
revoke access
change privileged roles
```

Frontend code should not be trusted to perform these directly.

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

/purchases
  /checkout
  /history

/profile

/admin
  /academic
  /courses
  /content
  /users
  /payments

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
    payments/
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

Content:

```text
draft
  |
  v
submitted
  |
  v
under_review
  |
  +--> changes_requested
  |
  +--> rejected
  |
  v
approved
  |
  v
published
```

Payment:

```text
pending
  |
  +--> successful
  |
  +--> failed
  |
  +--> abandoned
```

Clear transitions reduce inconsistent states.

---

# 43. Important Invariants

## Academic

- One Course should not be duplicated for every Department.
- Levels must be configurable.
- Course Offering defines who takes a Course in a period.
- Exam mode belongs to Course Offering.

## Access

- Any student can buy any available Course Offering.
- Student profile does not restrict purchases.
- Profile changes do not modify existing access.
- Course Access is the source of truth for paid access.

## Practice

- Active CBT Attempts do not expose correct answers.
- Active Written Attempts do not expose model answers.
- Submitted Attempts are frozen.
- CBT scores come from submitted answers.
- Written evaluation is self-assessed in V1.

## Content

- Student-facing content must be published.
- Contributor submission is not automatic publication.
- Source/provenance should be retained where possible.

## Payments

- Successful payment verification is server-side.
- Frontend success screens do not themselves grant access.

---

# 44. Conceptual Entity Map

```text
USER
 |
 +-- PROFILE
 |
 +-- PAYMENTS
 |     |
 |     +-- PURCHASE
 |            |
 |            +-- PURCHASE ITEMS
 |                    |
 |                    v
 |              COURSE ACCESS
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
       +-- OFFERING DEPARTMENTS
       |
       +-- PRACTICE SETS
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
 +-- PUBLICATION
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
question_key_points
content_sources

attempts
attempt_answers
written_self_assessments

payments
purchases
purchase_items
course_access

content_submissions
content_reviews

user_roles
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
Course Access
Payments
Practice Sets
CBT Attempts
Written Attempts
Submission
Review
Self-Assessment
Progress
Admin Content Management
Basic Content Review
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
One purchased/allowed access
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
is the academic subject

COURSE OFFERING
is that Course being offered during a specific academic period

PROFILE
helps recommend relevant Courses

COURSE ACCESS
decides what the student has actually unlocked

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
