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
- how payments and access should work
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

The system can use this information to show courses that are relevant to the student.

This is for discovery and personalisation.

It should not necessarily stop the student from searching for or buying another available course if needed.


## 9. COURSE DISCOVERY, PROFILE CHANGES AND ACCESS INDEPENDENCE

A student's academic profile should help the platform recommend and organise courses, but it must not restrict which courses the student can purchase.

A student may need a course outside their current department or level for reasons such as:

- carrying over a failed course
- taking an additional course
- taking a shared or elective course
- preparing for a course outside the student's normal department
- changing department, level or academic period

The platform should follow this rule:

```text
ACADEMIC PROFILE = DISCOVERY / RECOMMENDATION

PURCHASED ACCESS = ACTUAL ACCESS
```

The student's profile may include:

- College
- Department
- Level
- Current academic session or year

Students should be allowed to update these details later.

Changing profile information must not remove, shorten or otherwise affect access to courses already purchased.

Example:

```text
Before profile change:

Department: Software Engineering
Level: 300 Level

Purchased:
- GST 301
- CSC 205
- SWE 303
```

If the student later changes to:

```text
Department: Software Engineering
Level: 400 Level
```

the existing purchased courses must remain available until their individual access periods expire.

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
Courses the student has purchased and still has access to

RELEVANT COURSES
Courses suggested from the student's current academic profile

BROWSE ALL COURSES
Browse by College, optionally filter by Department, or search directly
```

This means:

- any student can purchase any available course
- department and level are not access restrictions
- changing academic details does not affect previous purchases
- purchase/access records are the source of truth for what is unlocked
- academic profile data only helps personalise discovery

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
+--> No access -> Buy access
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

- courses relevant to the student's department and level
- courses already purchased
- recent practice activity
- progress in purchased courses
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

Each course contains practice sets.

A practice set is simply a grouped set of questions for that course.

Example:

CSC 301
|
+-- Set 1
+-- Set 2
+-- Set 3
+-- Set 4

Practice sets give students smaller, manageable practice sessions.

We do not need to introduce extra labels like "mock exam" or "full practice" for now.

If a future feature is needed, we should name it based on what it actually does.


## 14. CBT PRACTICE

A CBT practice set contains objective questions.

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
+-- Reviewed by: Content Manager

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

Possible roles:

Core Team
- product and technical decisions
- platform development
- operations oversight

Student Contributors
- help obtain current course materials
- help identify relevant past questions
- provide departmental/course context
- report outdated content

Content Manager
- review submitted materials
- verify questions and answers
- organise content
- approve content before publication
- handle reported errors

Contributors may eventually need to be paid.

This does not need to happen immediately, but the product should be designed with the understanding that content work has real value.


## 20. CONTENT WORKFLOW

A controlled content flow is better than allowing random content directly into production.

Suggested flow:

Material / Question found
|
v
Submitted
|
v
Source identified
|
v
Reviewed
|
v
Questions prepared
|
v
Answers checked
|
v
Approved
|
v
Published

This gives the platform a quality-control layer.


## 21. PAYMENT AND ACCESS MODEL

The product will be paid, but pricing should remain fair for students.

The current direction is flexible course-based access rather than forcing students to buy an entire department or level package.

A student should be able to:

- buy one course
- buy several courses
- receive a discount when buying several courses

This is cleaner because students may not need every course at the same time.

Example:

Student selects:
- CSC 301
- SWE 303
- GST 301

Then chooses an access duration.


## 22. ACCESS DURATION

The current preferred structure is:

- 1 month
- 2 months
- 3 months

This is cleaner than making everybody expire on one semester date.

Example:

Student buys 2-month access on October 5.

Access expires on December 5.

This is easy to understand and fair because the student receives the duration they paid for regardless of when they bought.


## 23. BUNDLES

Bundles should give students flexibility.

Possible flow:

Select one or more courses
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
Access granted to selected courses

We do not need to finalise the exact discount formula yet.

The important product rule is:

Academic structure controls what is shown as relevant.

Payment controls what is unlocked.


## 24. WHY WE SHOULD NOT SELL ONLY BY DEPARTMENT OR LEVEL

Selling only by department or level creates extra complications.

It would require the system to perfectly know every course each student should have before access can be granted.

Course-based access is more flexible.

The platform can still recommend the student's department/level courses, while allowing them to buy only what they actually need.

Later, we can still introduce larger semester packages if users want them.


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
11. Payment
12. Access control
13. Content management
14. Content contribution and review
15. Administration


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
+--> No Access -> Payment -> Access Granted
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

Source Material
|
v
Contributor Submission
|
v
Content Review
|
v
Question Preparation
|
v
Verification
|
v
Publish
|
v
Course Practice Sets


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
- level
- departments
- exam mode

Practice Content
- practice sets
- questions
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

Commerce
- selected courses
- payment
- duration
- access start
- access expiry

Content Operations
- submissions
- contributors
- review status
- reviewer
- source records
- publication status


## 28. IMPORTANT ARCHITECTURAL RULES

The following ideas should guide implementation:

1. A course should not be duplicated simply because several departments take it.

2. Level values should not be hardcoded around 100 to 400 only.

3. Exam mode belongs to the course offering for the relevant academic period, not permanently to the course forever.

4. CBT and written practice should share a common attempt structure where possible, while still supporting their different answer types.

5. Students should not see written model answers before submission.

6. Course discovery and course access are separate systems.

7. Content should be traceable to its source where possible.

8. Content should be reviewed before publication.

9. Payment should unlock selected courses for a defined duration.

10. The architecture should allow future expansion without forcing the first version to include every future feature.


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
- course purchase/access
- 1, 2 and 3 month durations
- multi-course bundle support
- practice sets
- CBT answering and scoring
- written answering/skipping
- written review and self-assessment
- results
- progress
- basic admin/content management
- basic content review workflow

Things that do not need to be in V1:

- AI grading of written answers
- unnecessary gamification
- social features
- leaderboards
- complex lecturer portals
- advanced recommendation systems
- extra exam modes with vague names
- features added only because they sound impressive


## 30. FUTURE POSSIBILITIES

The architecture should leave room for future features without building them now.

Possible future additions:

- AI-assisted written answer feedback
- topic-based practice
- lecturer accounts
- richer contributor tools
- course-specific analytics
- stronger question reporting
- semester packages
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
- exact number of questions per set
- exact self-assessment labels
- detailed admin permissions
- exact contribution/reward model
- whether students can resume unfinished practice
- exact visual design
- detailed technical stack decisions
- how the three developers will divide development work

Those decisions should not stop us from agreeing on the product structure first.


## 33. CURRENT PRODUCT SUMMARY

We are building a paid but affordable exam preparation platform for Summit University students.

The platform understands:

College
-> Department
-> Level
-> Session
-> Semester
-> Course Offering

Each course offering has the examination mode that applies to it.

Students discover relevant courses, buy access to the courses they need, choose a 1, 2 or 3 month duration, and practise through structured question sets.

CBT courses are automatically scored.

Written courses allow students to type answers or skip questions, submit the full set, compare their answers with trusted model answers, and self-assess.

Content comes from trusted academic materials, past questions, student contributions and other relevant sources, but it should pass through a review process before publication.

The platform should eventually use a network of contributors and a content manager so that maintaining course content does not depend only on the three developers.

The next separate discussion should focus on how the three developers will work together to build this product without creating three disconnected codebases or conflicting implementations.
