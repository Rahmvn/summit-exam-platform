SUMMIT UNIVERSITY EXAM PRACTICE PLATFORM
SHORT TEAM OVERVIEW

## What are we building?

An exam preparation platform for Summit University students. Payments are
deferred beyond V1; the longer-term commercial direction can remain affordable.

It is not just a CBT app.

Some Summit courses are CBT and some are written, so the platform should support the actual exam mode of each course.

Main goal:

Make it easy for a student to open a course, practise relevant questions, submit, review and improve.


## The problem

Students already use:

- lecturer PDFs
- jottings
- past questions
- shared questions
- AI-generated questions

But preparation is scattered.

We want to turn that into one organised system.


## How Summit structure affects the app

University
|
+-- College
    |
    +-- Department
        |
        +-- Level

Then:

Academic Session
|
+-- Semester
    |
    +-- Course Offerings


A course can be:

- general
- shared by some departments
- specific to one department

We should create a course once, then define which departments/levels are taking it in a particular semester.

We should not hardcode only 100 to 400 Level because 500 Level is coming.


## Course offering

A course offering tells us:

- the course
- session
- semester
- zero or more Department + Level academic assignments
- exam mode
- expected Questions per Practice Set
- practice duration

Example:

GST 301
- 2026/2027
- First Semester
- Software Engineering, 300 Level
- Computer Science, 300 Level
- CBT


## Course discovery and access

A student's Department, Level and current Semester determine recommendations
through Course Offering academic assignments. College is structural browsing and
filter context; College alone does not recommend every course in that College.
Academic assignments do not authorize access or restrict which Course Offerings
may receive an access grant.

An Offering with zero assignments is valid. It will not appear in Department +
Level profile recommendations, which is a warning rather than a blocker for
Review or publication. It remains available for direct catalogue discovery and
Course Access where otherwise applicable. Assignment changes do not invalidate
Published content, terminate in-progress Attempts, or rewrite existing access or
purchase history.

```text
PROFILE = RECOMMENDATION

EFFECTIVE ACCESS POLICY = AUTHORIZATION
```

A student in one department must still be able to receive access to a course from another department.

This matters for students who:

- have carryover courses
- take additional or shared courses
- need a course outside their normal department
- change level, department or academic year

Students should be able to change their College, Department, Level or current
Semester later.

Changing those details must not affect existing Course Access Grants. Existing
grants stay active until expiry or trusted Admin revocation. Candidates may
access or later purchase Offerings outside their profile.

Course discovery should be College-first:

```text
Browse Courses
|
+-- College
    |
    +-- All Courses
    +-- Department filter
```

Students should also be able to search by course code or name.

The dashboard can distinguish:

- Your Courses: Course Offerings with effective access
- Relevant Courses: assignments matching Department + Level + current Semester
- Browse All Courses: unrestricted catalogue

## Student flow

Sign up / Log in
|
v
Choose College, Department, Level and current Semester
|
v
Dashboard shows relevant courses
|
v
Choose course
|
v
Server resolves effective access
|
v
Open practice set
|
v
Practise
|
v
Submit
|
v
Review
|
v
Progress updated


## Inside a course

CSC 301
CBT

Practice Sets
- Set 1
- Set 2
- Set 3

Progress


or


SWE 305
Written

Practice Sets
- Set 1
- Set 2
- Set 3

Progress


A course normally has the one exam mode that actually applies to it.

We do not need labels like "mock exam" or "full practice" for now.


## CBT practice

Student:

- selects answers
- moves between questions
- can leave questions unanswered
- submits
- gets automatic score
- reviews correct answer, own answer and explanation
- follows a server-authoritative timer snapshotted when the Attempt starts


## Written practice

Student:

- types an answer or skips
- does not see model answers before submission
- submits the full set
- reviews their own answer against our model answer
- sees important/expected points
- self-assesses
- follows the same server-authoritative timer

If time expires, unresolved Written Questions remain timed-out/unanswered. They
are not automatically marked as skipped.

Possible self-assessment:

- Got it
- Partially got it
- Did not get it

No AI grading is required for V1.


## Content

Questions can come from:

- lecturer PDFs
- lecture materials
- jottings
- past questions
- questions obtained from lectures
- manually created questions
- AI-generated questions based on trusted material

The Practice Set is the only content publication unit. Questions do not have an
independent editorial/publication lifecycle; their eligibility is derived from
integrity, active state and a valid Practice Set mapping. `questions.is_active`
remains an operational kill switch.

V1 Admin flow:

Course
|
v
Course Offering
|
v
Practice Set (draft)
|
v
Add/import Questions
|
v
Validate structural completeness
|
v
Practice Set (review)
|
v
Revalidate and publish


Bulk import is V1: upload, parse, validate, preview, confirm, then create all
Questions and mappings atomically. Questions remain reusable underneath, but
there is no Question Pool-first Admin UI in V1.

V1 roles are Candidate and Admin only. Contributor and Content Manager roles may
be considered later.


## Access and future payments

Payments and bundles are deferred beyond V1. V1 uses trusted manual Admin Course
Access grant/revoke operations with reasons, integrity and append-only audit.

The platform policy supports `free`, `free_until` and `grant_required`. `free`
requires no individual grant. `free_until` permits new starts before the
server-side cutoff without an individual grant; at or after the cutoff, an active
Course Access Grant authorizes new starts while the stored mode remains
`free_until`. No scheduler, Admin action or policy mutation is required at the
cutoff. An Attempt validly started before it may finish afterward subject to its
own deadline. `grant_required` also requires an active effective Course Access
Grant. The runtime should evaluate this centrally; the browser must not assemble
the decision itself.

Future direction:

- students buy individual Course Offerings, including off-profile Offerings
- students can buy an academic bundle/package
- bundles can get discounts
- access duration can be 1 month, 2 months or 3 months

Example:

Student buys either:
- CSC 301 individually
- an academic bundle explicitly containing CSC 301, SWE 303 and GST 301

Duration:
2 months

An academic bundle is scoped by Department, Level, Academic Session and Semester.
Its Course Offering composition is explicit. Academic assignments may suggest the
contents, but later assignment changes must not silently rewrite an existing
package or an existing purchase.

Trusted purchase processing produces Course Access Grants for each included
Offering. Those grants authorize starts in `grant_required` mode and after a
`free_until` cutoff; payment itself never authorizes access. An individual
Offering purchase never requires a prior Department/Level package purchase.


## Main systems

The platform will need:

- authentication
- student profile
- academic structure
- courses and course offerings
- practice sets
- CBT practice
- written practice
- attempts and answers
- results and progress
- course access control
- content management
- content review
- admin tools


## Simple architecture view

STUDENT SIDE

Student
|
v
Profile
|
v
Relevant Courses
|
v
Course Access
|
v
Course
|
v
Practice Set
|
+--> CBT -> Submit -> Score -> Review
|
+--> Written -> Submit -> Compare -> Self-assess
|
v
Progress


CONTENT SIDE

Course -> Course Offering -> Practice Set (Draft)
  -> Add/import Questions -> Validate -> Review -> Publish


## Important rules

- Do not duplicate one course for every department.
- Do not assume 400 Level is the maximum forever.
- Do not assume every course has both CBT and written modes.
- Written answers stay hidden until submission.
- Course recommendations and course access are separate things.
- Questions should be traceable to their source where possible.
- Content should be reviewed before publication.
- Practice Set is the only publication lifecycle: Draft, Review, Published, Archived.
- Effective access is centrally resolved from `free`, the pre-cutoff
  `free_until` window, or an active Course Access Grant under `grant_required`
  and post-cutoff `free_until`.
- Payment is never authorization; trusted purchase processing may produce grants.
- Timers are server-authoritative; browser countdowns are presentation only.


## V1 should focus on

- signup/login
- academic profile
- course discovery
- centralized effective-access policy
- manual Admin course access grant/revoke
- practice sets
- timed practice
- bulk Question import
- CBT scoring/review
- written answer/skip/review/self-assessment
- progress
- basic admin/content workflow
- Admin audit before consequential mutation APIs

Not needed now:

- AI grading
- leaderboards
- social features
- complex lecturer portals
- payments and bundles
- Content Manager role and content version subsystems
- unnecessary extra practice modes


## What we discuss next

After we all agree on this product structure, the next discussion should be:

HOW THE THREE OF US WILL BUILD IT TOGETHER.

That includes:

- one codebase
- responsibilities
- architecture ownership
- branches
- integration
- reviews
- how we avoid three developers building three different versions of the same product
