SUMMIT UNIVERSITY EXAM PRACTICE PLATFORM
DETAILED PRODUCT AND SYSTEM PLAN

## Purpose

This document explains what we are building before development begins.

It is meant to give the team one shared understanding of:

- who the product is for
- the problem we are solving
- how Summit University's academic structure affects the product
- how students will move through the platform
- how CBT and written practice should work
- how courses, questions and content should be organised
- how access should work while payments are deferred
- how content should be sourced and reviewed
- the major systems the application will need

This is not yet the document for dividing development work between the three developers.
That should be discussed separately after the product and system structure are agreed.


## 1. PRODUCT DEFINITION

We are building an exam preparation platform for Summit University students.

The product should make it easier for students to prepare for their actual university exams in a structured and practical way.

It should not be treated as only a CBT app.

Summit University is shifting many courses toward CBT, but written examinations still exist.

Because of that, the platform should support two kinds of course practice:

- CBT practice
- Written practice

A course should normally use the practice type that matches how that course is being examined for that academic period.

We should not assume that every course has both CBT and written modes.

The main idea is simple:

Students should be able to open the platform, find the course they are preparing for, practise relevant questions, submit, review their work and improve.


## 2. THE PROBLEM

Students already prepare for exams in different ways.

Common methods include:

- lecturer PDFs
- lecture materials
- personal jottings
- past questions
- questions shared by other students
- AI-generated questions based on course materials

The problem is not that students have no material.

The problem is that preparation is scattered.

A student may need to:

- search for the right PDF
- upload it to an AI tool
- ask AI to generate questions
- decide whether the generated questions are good
- practise somewhere else
- repeat the same process for several courses

The platform should reduce that friction.

Instead of every student building a separate preparation process for themselves, the platform should provide a ready and organised practice environment for each course.


## 3. TARGET USERS

The initial users are Summit University undergraduate students.

The platform should be built around the university's academic structure.

Current level structure:

- 100 Level
- 200 Level
- 300 Level
- 400 Level

500 Level will exist in future years, so the system must not hardcode the current levels as a fixed permanent list.

Levels should be configurable data.


## 4. SUMMIT UNIVERSITY ACADEMIC STRUCTURE

The university is organised roughly like this:

University
|
+-- College
    |
    +-- Department
        |
        +-- Level
            |
            +-- Courses

However, courses should not be stored as though they permanently belong to only one department.

Some courses are:

- general courses
- shared by several departments
- specific to one department

So we need to separate two ideas:

1. The course itself
2. The fact that the course is being offered to certain students during a certain semester/session

Example:

Course:
GST 301

Course Offering:
- Academic session: 2026/2027
- Semester: First Semester
- Level: 300 Level
- Departments: Software Engineering, Computer Science, etc.
- Exam mode: CBT

This avoids creating duplicate copies of the same course for every department.


## 5. ACADEMIC SESSION AND SEMESTER

The university uses:

- First Semester
- Second Semester

The courses in First Semester are not necessarily the same as the courses in Second Semester.

Some courses may appear only in one semester.

If the same course is offered to multiple departments in the same period, it should still be treated as the same course and same course content.

This means the system should understand:

Academic Session
|
+-- Semester
    |
    +-- Course Offerings


## 6. COURSE OFFERING

A course offering is important because some information may change from one academic period to another.

A course offering should be able to describe:

- course
- academic session
- semester
- level
- departments taking it
- examination mode
- expected Questions per Practice Set
- practice duration

Practice duration is configured in minutes in the Admin experience and may be
represented in seconds internally. Expected Question count and duration apply
to every Practice Set in the Offering; V1 has no per-set overrides.

This also helps if the examination mode changes later.

For example:

CSC 301 may be CBT this year and written in another year.

The identity of CSC 301 should not change.

Only the course offering details for that period should change.


## 7. EXAMINATION MODE

For the initial product, a course offering can be:

- CBT
- Written

A normal course should not display both modes unless the course genuinely uses both.

Example:

CSC 301
Exam Mode: CBT

or

SWE 305
Exam Mode: Written


## 8. STUDENT PROFILE

A student should create an account and provide basic academic information.

Likely profile information:

- College
- Department
- Level
- Current Semester

Department, Level and current Semester determine which Course Offerings are
recommended. College provides structure and browsing/filter context; College by
itself must not make every Course Offering in that College recommended.

This is for discovery and personalisation.

It should not stop the student from searching for or receiving access to another available course if needed.


## 9. COURSE DISCOVERY, PROFILE CHANGES AND ACCESS INDEPENDENCE

A student's academic profile should help the platform recommend and organise courses, but it must not restrict which Course Offerings may receive an access grant.

A student may need a course outside their current department or level for reasons such as:

- carrying over a failed course
- taking an additional course
- taking a shared or elective course
- preparing for a course outside the student's normal department
- changing department, level or academic period

The platform should follow this rule:

```text
ACADEMIC PROFILE = DISCOVERY / RECOMMENDATION

EFFECTIVE ACCESS POLICY = AUTHORIZATION
```

The student's profile may include:

- College
- Department
- Level
- Current Semester

Students should be allowed to update these details later.

Changing profile information must not remove, shorten or otherwise affect existing Course Access Grants.

Example:

```text
Before profile change:

Department: Software Engineering
Level: 300 Level

Active access:
- GST 301
- CSC 205
- SWE 303
```

If the student later changes to:

```text
Department: Software Engineering
Level: 400 Level
```

the existing access grants must remain available until their individual access periods expire or are revoked by a trusted Admin operation.

The profile change should only affect what the platform recommends or shows first.

Course browsing should therefore be open.

The preferred discovery structure is College-first browsing, with department used as an optional filter rather than a restriction.

Example:

```text
Browse Courses

College A
  - All Courses
  - Department 1
  - Department 2
  - Department 3

College B
  - All Courses
  - Department 1
  - Department 2
```

Students should also be able to search directly by course code or course name.

The dashboard can separate:

```text
YOUR COURSES
Course Offerings for which the student has active access

RELEVANT COURSES
Offerings assigned to the student's Department + Level in the current Semester

BROWSE ALL COURSES
Browse by College, optionally filter by Department, or search directly
```

This means:

- any Candidate may receive access to any available Course Offering
- department and level are not access restrictions
- changing academic details does not affect existing access grants
- academic assignment determines relevance, not authorization
- centralized effective-access policy determines whether a new Attempt may start
- academic profile data only helps personalise discovery

A Course Offering may validly have zero academic assignments. In that case it
does not appear in Department + Level profile recommendations, but remains
eligible for direct catalogue discovery and Course Access under the same rules
as any other Offering. Zero assignments is a readiness warning, not a blocker
for Review or publication. Assignment changes do not invalidate Published
content, terminate an in-progress Attempt, or rewrite existing access or
purchase history.

## 10. MAIN STUDENT FLOW

The basic flow should be:

Open platform
|
v
Sign up / Log in
|
v
Complete academic profile
|
v
Dashboard
|
v
See relevant courses
|
v
Choose a course
|
v
Check access
|
+--> No effective access -> Access unavailable
|
v
Open course
|
v
Choose practice set
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


## 11. DASHBOARD

The dashboard should help the student continue preparing.

It should not be filled with unnecessary information.

Useful dashboard information may include:

- courses relevant to the student's Department, Level and current Semester
- courses with effective access
- recent practice activity
- progress in courses with effective access
- access expiry dates
- unfinished attempts, if we choose to support continuation

The exact design can be decided later.


## 12. COURSE PAGE

A course page should stay simple.

Example for a CBT course:

CSC 301
CBT

Practice Sets
- Set 1
- Set 2
- Set 3
- Set 4

Progress


Example for a written course:

SWE 305
Written

Practice Sets
- Set 1
- Set 2
- Set 3

Progress

There is no need for separate "CBT Practice" and "Written Practice" sections inside every course.

The exam mode of the course determines how its practice sets behave.


## 13. PRACTICE SETS

Each Course Offering contains Practice Sets.

A practice set is simply a grouped set of questions for that course.

Example:

CSC 301
|
+-- Set 1
+-- Set 2
+-- Set 3
+-- Set 4

Practice sets give students smaller, manageable practice sessions.

The Practice Set is the only content publication unit. Its lifecycle is:

```text
draft -> review -> published -> archived
```

There is no Approved Practice Set state. Questions do not have an independent
editorial or publication lifecycle. Their eligibility is derived from data
integrity, operationally active state, exam-mode requirements and valid mapping
to the Practice Set. `questions.is_active` remains an operational kill switch.

Sending a Set to Review requires the exact Offering-configured Question count,
valid ordered mappings, same-Offering integrity, active Questions and all
required CBT or Written data. Publishing requires the Set to already be in
Review and the readiness check to still pass.

We do not need to introduce extra labels like "mock exam" or "full practice" for now.

If a future feature is needed, we should name it based on what it actually does.


## 14. CBT PRACTICE

A CBT practice set contains objective questions.

Practice is timed using the duration configured on the Course Offering. A new
Attempt snapshots that duration and a server-authoritative deadline. The browser
countdown is presentation only.

The student should be able to:

- select an answer
- move forward and backward
- see answered and unanswered questions
- leave questions unanswered
- change an answer before submission
- submit the set
- receive an automatic score
- review all questions after submission

Basic flow:

Open CBT set
|
v
Answer questions
|
v
Navigate through set
|
v
Submit
|
v
Score calculated
|
v
Review


CBT review can show:

- question
- student's answer
- correct answer
- explanation, where available
- source/reference, where useful


## 15. WRITTEN PRACTICE

Written practice is self-assessed.

Written practice uses the same server-authoritative timer model as CBT. If time
expires, unresolved Questions remain timed-out/unanswered; they are not
automatically marked as skipped.

We should not pretend the system can perfectly grade written answers in the first version.

For each question, the student can:

- type an answer
- skip the question

The student should not see the model answer before submitting the set.

This keeps the session as real practice rather than turning it into simple reading.

Basic flow:

Open written set
|
v
Read question
|
+--> Type answer
|
+--> Skip
|
v
Continue through questions
|
v
Submit
|
v
Review
|
v
Self-assess


During review, each question can show:

Question

Your answer:
[student response]

or

Skipped

Model answer:
[trusted answer]

Expected / important points:
- point 1
- point 2
- point 3

Self-assessment:
- Got it
- Partially got it
- Did not get it

The exact labels can still be adjusted later.

The key idea is that the student compares their own answer with the model answer and judges their understanding.


## 16. PROGRESS

Progress should be based on actual practice activity.

For CBT, useful progress information can include:

- sets attempted
- scores
- attempts
- improvement over time
- questions reviewed

For written courses, progress can include:

- sets attempted
- questions answered
- questions skipped
- self-assessment results
- areas marked as weak

We should keep progress useful and simple in V1.

We do not need unnecessary gamification at the beginning.


## 17. CONTENT SOURCES

The platform may use content from several sources.

Possible sources include:

- lecturer PDFs
- lecture materials
- student jottings
- verified past questions
- questions obtained from lectures
- manually created questions
- AI-generated questions based on trusted materials

These sources should not all be treated as equally reliable.

For example:

Lecturer material is generally more authoritative than random student notes.

A verified past question is stronger than an unconfirmed question someone says came out before.

The system should retain information about where content came from.

This is content provenance.


## 18. CONTENT PROVENANCE

Where possible, a question should be traceable to its source.

For example:

Question
|
+-- Based on lecturer PDF
+-- Course: CSC 301
+-- Topic: Database Normalisation
+-- Source note: Week 4 material
+-- Reviewed by: Admin

This becomes useful when:

- a student reports an answer as wrong
- the team needs to verify a question
- a lecturer changes course material
- content needs to be updated
- AI-generated content needs checking

We should not publish content blindly just because AI generated it.


## 19. CONTENT OPERATIONS

The three developers should not be expected to personally source and maintain every course across the university.

The product will likely need a wider content network.

V1 operational roles:

Admin
- product and technical decisions
- platform development
- operations oversight
- review submitted materials
- verify questions and answers
- organise content
- publish complete Practice Sets
- handle reported errors

Candidate is the only other V1 role. There is no Content Manager role or detailed
permission matrix in V1. Student contribution and narrower content roles may be
considered later without changing the Candidate/Admin boundary now.


## 20. CONTENT WORKFLOW

A controlled content flow is better than allowing random content directly into production.

The V1 Admin authoring flow is Practice Set-first:

Course
|
v
Course Offering
|
v
Practice Set (draft)
|
v
Add Questions manually or import them in bulk
|
v
Validate structural completeness
|
v
Practice Set (review)
|
v
Revalidate readiness
|
v
Practice Set (published)

Questions remain reusable underlying entities through ordered mappings, but V1
does not use a Question Pool-first Admin UI.

Bulk Question Import is V1:

```text
upload -> parse -> validate -> preview -> confirm -> atomic commit
```

The confirmed import creates Questions and mappings in one transaction so a
failure cannot leave partial content.

Frozen Attempt snapshots protect historical Attempts. A substantive correction
to a reused Question must not silently change every published Practice Set that
uses it. V1 prefers impact-aware replacement and explicit remapping; harmless
typo, formatting or reference corrections may be audited in place. Formal
Question and Practice Set version subsystems are not part of V1.

Append-only Admin audit data must exist before consequential Admin mutation APIs.
No Activity UI is required in V1.


## 21. ACCESS MODEL AND FUTURE PAYMENTS

Payments and purchase flows are deferred beyond V1. Manual Admin Course Access
grant/revoke remains V1.

The platform access policy supports:

```text
free           -> no individual Course Access Grant required
free_until     -> before cutoff no grant required; at/after cutoff an active grant is required
grant_required -> an active effective Course Access Grant is required
```

Effective access must eventually be evaluated centrally by trusted runtime logic;
the browser must not independently combine policy mode, cutoff and grant state.
Reaching a `free_until` cutoff does not change the stored policy mode and requires
no scheduler, Admin action or database mutation. An active individual Course
Access Grant authorizes a new Attempt after the cutoff.
An Attempt validly started during a `free_until` window may finish after the
cutoff, subject to its own snapshotted authoritative deadline.

When grants are required, including after a `free_until` cutoff, Course Access is
the authorization primitive. Admins need trusted APIs to inspect Candidate and
Offering grants, grant or revoke with reasons, preserve history, enforce
integrity and record append-only audit data.

The product may later be paid, but pricing should remain fair for students.

Future commerce is hybrid rather than package-only.

A student should be able to:

- buy an individual Course Offering, including one outside their profile
- buy an academic bundle/package
- buy an individual Offering without first buying their Department/Level package

This is cleaner because students may not need every course at the same time.

Example:

Student selects either:
- CSC 301 as an individual Course Offering
- a defined academic bundle containing CSC 301, SWE 303 and GST 301

Then chooses an access duration.


## 22. FUTURE PURCHASE DURATION

The current preferred structure is:

- 1 month
- 2 months
- 3 months

This is cleaner than making everybody expire on one semester date.

Example:

Student buys 2-month access on October 5.

Access expires on December 5.

This is easy to understand and fair because the student receives the duration they paid for regardless of when they bought.


## 23. FUTURE BUNDLES

An academic bundle/package is scoped by:

- Department
- Level
- Academic Session
- Semester

Its composition is an explicit list of Course Offerings. Course academic
assignments may suggest or initially populate the list, but later assignment
changes must not silently rewrite an existing package or what an existing
purchase contained.

Possible flow:

Choose an academic bundle
|
v
System calculates total
|
v
Bundle discount applied where eligible
|
v
Choose duration
|
v
Pay
|
v
Course Access granted to every included Course Offering

We do not need to finalise the exact discount formula yet.

The important product rule is:

Academic assignments control what is shown as relevant.

When grants are required, Course Access Grants control what is unlocked. A future
individual purchase, academic bundle purchase, manual Admin action or institutional
grant may produce them through trusted processing. Payment itself is never
authorization.


## 24. WHY WE SHOULD NOT SELL ONLY BY DEPARTMENT OR LEVEL

Selling only by department or level creates extra complications.

It would require the system to perfectly know every course each student should have before access can be granted.

The platform therefore supports individual Course Offering purchase alongside
academic bundles, rather than making a bundle a prerequisite.

If payments are introduced later, the platform can still recommend the
student's department/level courses while allowing them to buy only what they
actually need.

Academic bundles remain explicitly scoped and contain explicit Course Offerings;
they are not generated dynamically at authorization time from current assignments.


## 25. MAJOR PRODUCT SYSTEMS

At a high level, the application needs these systems:

1. Authentication
2. Student profile
3. Academic structure
4. Course catalogue
5. Course offerings
6. Practice sets
7. CBT practice engine
8. Written practice engine
9. Attempt and answer storage
10. Results and progress
11. Access control
12. Content management
13. Content contribution and review
14. Administration

Payment and bundle commerce are future systems, not V1 systems.


## 26. HIGH-LEVEL SYSTEM SKETCH

STUDENT SIDE

Student
|
v
Authentication
|
v
Student Profile
|
v
Relevant Courses
|
v
Course Access Check
|
+--> Central policy resolver -> Access Granted or Unavailable
|
v
Course
|
v
Practice Set
|
+--> CBT -> Answers -> Submit -> Score -> Review
|
+--> Written -> Answers/Skip -> Submit -> Review -> Self-assess
|
v
Progress


CONTENT SIDE

Course -> Course Offering -> Practice Set (draft)
  -> Add/import Questions -> Validate -> Review -> Publish


## 27. CONCEPTUAL DATA STRUCTURE

This is not yet the final database schema.

It is only the main information the system needs to understand.

Users
- account
- profile
- department
- level

Academic Structure
- colleges
- departments
- levels
- academic sessions
- semesters

Courses
- course code
- course title

Course Offerings
- course
- session
- semester
- zero or more Department + Level academic assignments
- exam mode
- expected Questions per Practice Set
- practice duration

Practice Content
- practice sets
- Practice Set lifecycle: draft, review, published, archived
- questions
- ordered Practice Set Question mappings
- options for CBT
- correct answers
- model answers for written
- expected key points
- explanations
- references
- source information

Attempts
- student
- practice set
- answers
- skipped questions
- submission status
- score for CBT
- written self-assessment
- timestamps
- duration snapshot
- authoritative deadline

Access
- platform policy: free, free_until or grant_required
- centralized effective-access result
- Course Offering grant
- access start
- access expiry
- optional revocation
- Admin reason and audit

Future Commerce
- individual Course Offering purchase
- academic bundle scoped by Department, Level, Academic Session and Semester
- explicit bundle Course Offering items
- purchased composition snapshot
- resulting Course Access Grants for every purchased Offering

Content Operations
- submissions
- contributors
- review status
- reviewer
- source records
- Practice Set publication status
- Admin audit


## 28. IMPORTANT ARCHITECTURAL RULES

The following ideas should guide implementation:

1. A course should not be duplicated simply because several departments take it.

2. Level values should not be hardcoded around 100 to 400 only.

3. Exam mode belongs to the course offering for the relevant academic period, not permanently to the course forever.

4. CBT and written practice should share a common attempt structure where possible, while still supporting their different answer types.

5. Students should not see written model answers before submission.

6. Course discovery and course access are separate systems.

7. Content should be traceable to its source where possible.

8. Practice Sets should pass readiness, Review and revalidation before publication.

9. Effective access is centrally resolved from `free`, the pre-cutoff
   `free_until` window, or an active Course Access Grant under `grant_required`
   and post-cutoff `free_until`; payment is never authorization.

10. Timer authority is server-side; the browser countdown is presentation only.

11. The architecture should allow future expansion without forcing the first version to include every future feature.


## 29. V1 SCOPE

The first usable version should focus on the core preparation experience.

V1 should include:

- account creation and login
- student academic profile
- colleges, departments and levels
- academic sessions and semesters
- courses
- course offerings
- CBT and written exam mode support
- course discovery
- centralized effective-access policy with `free`, `free_until` and `grant_required`
- manual Admin Course Access grant/revoke
- practice sets
- Practice Set-first Admin authoring
- bulk Question import with atomic commit
- server-authoritative timed practice
- CBT answering and scoring
- written answering/skipping
- written review and self-assessment
- results
- progress
- basic admin/content management
- basic content review workflow
- append-only Admin audit before consequential mutation APIs

Things that do not need to be in V1:

- AI grading of written answers
- unnecessary gamification
- social features
- leaderboards
- complex lecturer portals
- advanced recommendation systems
- extra exam modes with vague names
- features added only because they sound impressive
- payment and bundle commerce
- Content Manager role or detailed permission matrix
- Question-version or Practice-Set-version subsystems


## 30. FUTURE POSSIBILITIES

The architecture should leave room for future features without building them now.

Possible future additions:

- AI-assisted written answer feedback
- topic-based practice
- lecturer accounts
- richer contributor tools
- course-specific analytics
- stronger question reporting
- academic bundle/package commerce
- revision recommendations
- more universities

These should not distract the team from getting the first version right.


## 31. PRODUCT PRINCIPLE

The product should feel simple to the student even if the system behind it is complex.

A student should mainly think:

"I have an exam for this course. I want to practise."

The platform should then make the rest straightforward.

The complexity of colleges, departments, semesters, access control, content review and question sourcing should mostly stay behind the scenes.


## 32. WHAT IS STILL NOT DECIDED

The following can be decided later:

- product name
- exact pricing
- exact bundle discount formula
- access-policy configuration ownership
- exact backend storage and time-zone representation for the authoritative `free_until` cutoff
- whether `My Courses` should include every accessible Offering while the platform is free
- bundle editing rules after publication and the exact purchase-composition snapshot mechanism
- exact Offering configurations for Question count and duration
- exact self-assessment labels
- future permissions beyond Candidate and Admin
- exact contribution/reward model
- exact legacy treatment for pre-timer Attempts beyond preserving no invented deadline
- exact visual design
- detailed technical stack decisions
- how the three developers will divide development work

Those decisions should not stop us from agreeing on the product structure first.


## 33. CURRENT PRODUCT SUMMARY

We are building an exam preparation platform for Summit University students.
Payments are deferred beyond V1.

The platform understands:

College
-> Department
-> Level
-> Session
-> Semester
-> Course Offering

Each course offering has the examination mode that applies to it.

Students discover relevant Courses through Department + Level + current Semester
assignments, receive centrally evaluated effective access, and practise through
structured timed Practice Sets. Manual Admin Course Access grant/revoke remains V1;
payment and bundle commerce remain deferred.

CBT courses are automatically scored.

Written courses allow students to type answers or skip questions, submit the full set, compare their answers with trusted model answers, and self-assess.

Content comes from trusted academic materials, past questions and other relevant
sources. The Practice Set is the publication unit and must pass readiness,
Review and revalidation before publication.

The platform may eventually use a network of contributors and narrower content
roles, but V1 roles remain Candidate and Admin.

The next separate discussion should focus on how the three developers will work together to build this product without creating three disconnected codebases or conflicting implementations.
