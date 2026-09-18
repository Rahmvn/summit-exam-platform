SUMMIT UNIVERSITY EXAM PRACTICE PLATFORM
SHORT TEAM OVERVIEW

## What are we building?

A paid but affordable exam preparation platform for Summit University students.

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
- level
- departments taking it
- exam mode

Example:

GST 301
- 2026/2027
- First Semester
- 300 Level
- several departments
- CBT


## Course discovery and access

A student's academic details should guide recommendations, not restrict what they can buy.

```text
PROFILE = RECOMMENDATION

PURCHASE = ACCESS
```

A student in one department must still be able to purchase a course from another department.

This matters for students who:

- have carryover courses
- take additional or shared courses
- need a course outside their normal department
- change level, department or academic year

Students should be able to change their College, Department, Level or academic year later.

Changing those details must not affect courses they already purchased. Existing purchases stay active until their normal expiry date.

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

- Your Courses: what the student purchased
- Relevant Courses: recommendations based on profile
- Browse All Courses: unrestricted catalogue

## Student flow

Sign up / Log in
|
v
Choose College, Department and Level
|
v
Dashboard shows relevant courses
|
v
Choose course
|
v
Buy access if needed
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


## Written practice

Student:

- types an answer or skips
- does not see model answers before submission
- submits the full set
- reviews their own answer against our model answer
- sees important/expected points
- self-assesses

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

But content should not go straight into the app.

Suggested flow:

Material found
|
v
Submitted
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


We will likely need student contributors for different departments/courses and a trusted content manager.

These people may eventually need to be paid.


## Payments

Best current direction:

- students buy individual courses
- students can select several courses as a bundle
- bundles can get discounts
- access duration can be 1 month, 2 months or 3 months

Example:

Student buys:
- CSC 301
- SWE 303
- GST 301

Duration:
2 months

All selected courses are unlocked for that period.

This is cleaner than forcing students to buy a whole department or level package.


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
- payments
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
Access / Payment
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

Materials
|
v
Contributors
|
v
Review
|
v
Verification
|
v
Publish
|
v
Practice Sets


## Important rules

- Do not duplicate one course for every department.
- Do not assume 400 Level is the maximum forever.
- Do not assume every course has both CBT and written modes.
- Written answers stay hidden until submission.
- Course recommendations and course access are separate things.
- Questions should be traceable to their source where possible.
- Content should be reviewed before publication.
- Payment unlocks selected courses for a fixed duration.


## V1 should focus on

- signup/login
- academic profile
- course discovery
- course purchase/access
- practice sets
- CBT scoring/review
- written answer/skip/review/self-assessment
- progress
- basic admin/content workflow

Not needed now:

- AI grading
- leaderboards
- social features
- complex lecturer portals
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
