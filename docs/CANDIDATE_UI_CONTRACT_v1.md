# Summit Exam Platform
## Candidate UI Contract v1

**Status:** Locked design direction for Candidate-facing UI foundation
**Purpose:** Establish the shared Candidate information architecture, shell behavior, interaction patterns, visual language, responsive rules, and accessibility expectations before implementation and parallel feature development.

> **Core principle:** The interface should explain itself through hierarchy, placement, labels, state, and obvious actions. Avoid unnecessary explanatory copy, excessive headings, decorative complexity, and duplicated information.

References such as PromotionSure and other education products are evidence, not templates. Patterns should be reused when they fit Summit, improved when necessary, and rejected only when they conflict with Summit’s product model or user needs.

---

# 1. Candidate Information Architecture

The normal Candidate application begins with two guaranteed top-level destinations:

- **Home**
- **Courses**

`Progress` is planned, but it should not receive a permanent navigation position until it has enough real value to justify one.

Account is accessible through the user/avatar control. Help and Support are available through Account and may also be linked contextually from relevant error or access states.

## Desktop navigation

```text
┌──────────────────────────────────────────────────────┐
│ Summit Exam       Home     Courses             [AR] │
└──────────────────────────────────────────────────────┘
```

When Progress becomes worthwhile:

```text
Summit Exam     Home     Courses     Progress      [AR]
```

## Mobile navigation

```text
┌──────────────────────────────┐
│ Summit Exam             [AR] │
├──────────────────────────────┤
│                              │
│        page content          │
│                              │
├──────────────────────────────┤
│      Home       Courses      │
└──────────────────────────────┘
```

When Progress becomes worthwhile:

```text
Home      Courses      Progress
```

Do not reserve empty navigation destinations merely for symmetry.

---

# 2. Candidate Shell

The normal Candidate shell provides:

- product identity
- primary navigation
- account control
- consistent page container
- consistent responsive gutters
- mobile bottom navigation
- global network/session state only when genuinely necessary

The shell should not wrap every section inside another titled card. Cards represent meaningful objects or actions, not arbitrary section boundaries.

Prefer:

```text
Welcome back, Abdulrahman
Software Engineering · 200 Level · First Semester

Continue practising
...

Recommended for you
...
```

Avoid nested compositions such as:

```text
Dashboard card
  Welcome card
  Continue card
  Recommended Courses card
    Course cards
```

---

# 3. Visual Language

The Candidate UI should feel:

- modern
- calm
- academic
- lightweight
- student-friendly
- highly readable
- direct

It should not look like:

- a generic SaaS dashboard
- an admin panel
- a banking app
- PromotionSure with renamed labels
- an AI-themed interface

## Visual direction

```text
light neutral canvas
white surfaces
dark neutral typography
green primary action
gold used sparingly
thin borders
minimal elevation
```

Avoid:

- gradients
- glassmorphism
- glows
- excessive badges
- giant shadows
- decorative charts without real utility
- oversized iconography
- excessive card nesting

## Foundation color roles

Exact production values may be refined during implementation, but the role system is fixed.

| Token | Role |
|---|---|
| Canvas | very light warm/neutral application background |
| Surface | white |
| Primary text | dark neutral |
| Muted text | medium neutral |
| Primary | deep green |
| Primary hover | darker green |
| Soft primary | light green surface |
| Accent | restrained gold |
| Soft accent | light gold surface |
| Border | quiet neutral |
| Success | green semantic treatment |
| Warning | amber/gold semantic treatment |
| Error | red semantic treatment |

Gold is not a second primary CTA color.

---

# 4. Typography

Use a highly readable modern sans-serif, likely **Geist** or a similarly clean Next.js-friendly font.

Approximate hierarchy:

| Role | Desktop | Mobile |
|---|---:|---:|
| Major page title | 30–32px | 26–28px |
| Section title | 21–24px | 20–22px |
| Card/title | 17–18px | 16–18px |
| Body | 16px | 16px |
| Metadata | 14px | 14px |
| Small helper | 13px | 13px |

Normal application pages should not use giant marketing-style headings.

Use **Welcome back, [first name]** rather than time-of-day greetings such as “Good evening.”

---

# 5. Layout System

Normal Candidate pages should share one consistent layout contract.

```text
Desktop max content width: ~1180px
Desktop horizontal gutters: 24–32px
Tablet gutters: ~20px
Mobile gutters: 16px
```

## Shared spacing vocabulary

```text
4 / 8 / 12 / 16 / 24 / 32 / 48 / 64
```

## Normal surfaces

```text
~12px radius
1px border
little or no shadow
```

## Interactive controls

Normal buttons, navigation targets, option controls, and question-map targets should aim for approximately **44px minimum interactive size** where practical.

---

# 6. Home

Home answers:

> **What should I practise now?**

It is not a full catalogue and not an analytics dashboard.

## Structure

```text
Welcome back, Abdulrahman
Software Engineering · 200 Level · First Semester


Continue practising
┌─────────────────────────────────────────────┐
│ CSC 203 · Practice Set 2                    │
│ 8 of 20 answered · 18:42 left     Continue │
└─────────────────────────────────────────────┘

Only present when there is an active, unexpired Attempt. An Attempt whose server
deadline has passed must be finalized rather than offered as resumable.


Recommended for you

┌──────────────────────┐  ┌──────────────────────┐
│ CSC 201              │  │ SWE 203              │
│ Course title         │  │ Course title         │
│ CBT · First Semester │  │ Written · First Sem. │
│                      │  │                      │
│ View course          │  │ View course          │
└──────────────────────┘  └──────────────────────┘

View all courses
```

Do not include:

- a separate Your Courses section on Home
- average-score hero panels
- streaks
- decorative statistics
- giant access panels
- generic explanatory paragraphs
- empty Continue sections when nothing is active

## Recommended for you

Recommendation is driven by:

```text
Department
+ Level
+ Current Semester
```

College is derived naturally through Department.
It is structural browsing/filter context; College alone must not make every
Course Offering in that College recommended. A Course Offering may have multiple
Department + Level academic assignments, and a match against one of those
assignments determines relevance.

Recommendation does not equal access.

A recommended course may be locked. A course with effective access does not
become recommended merely because it was unlocked.

---

# 7. Courses

Courses is **one intelligent catalogue**, not multiple duplicated catalogue pages.

## Desktop

```text
Courses

[ Search by course code or title...                 ]

[ My courses ] [ College ▾ ] [ Department ▾ ] [ Level ▾ ] [ Semester ▾ ]


CSC 203
Data Structures and Algorithms
CBT · First Semester · 2026/2027
                                           View course

SWE 205
Software ...
Written · First Semester · 2026/2027
                                           View course
```

## Mobile

```text
Courses

[ Search courses... ]

[ My courses ]                 [ Filters ]

course results...
```

`Filters` opens a bottom sheet.

## Default catalogue state

The initial catalogue should reflect the student’s academic profile so the first results are naturally relevant.

Students can loosen or change filters:

- College
- Department
- Level
- Semester
- All

They can also search directly by course code or title.

The academic profile is a convenience for discovery, not a restriction.

---

# 8. My Courses

`My courses` is a filter/state of the Courses catalogue.

It means:

> Show the Course Offerings I currently have access to.

It is independent of College, Department, and Level.
The list must consume the server's centralized effective-access result, not
reconstruct access from policy mode, cutoff and grants in the browser. The exact
`My courses` presentation when `free` makes the full active catalogue accessible
still requires a product decision.

Example:

```text
Student profile:
Software Engineering · 200 Level

Student has active access to:
ECO 201

My courses:
CSC 203
SWE 205
ECO 201
```

Do not label an unlocked off-profile course as:

- outside your department
- external course
- unusual course

It is simply one of the student’s courses.

Quiet Offering metadata is enough:

```text
ECO 201
Principles of Economics
CBT · First Semester · 2026/2027
```

Profile changes must never remove existing Course Access. Candidates may access
or later purchase an individual Course Offering outside their current academic
profile, without first purchasing a Department/Level package.

---

# 9. Course Page

The Course page answers:

> **What can I practise for this course?**

Keep the page concise.

```text
← Courses

CSC 203
Data Structures and Algorithms

CBT · First Semester · 2026/2027

Access until 20 December


Practice sets

Practice duration: 30 minutes

┌──────────────────────────────────────────┐
│ Set 1                       20 questions │
│                                    Start │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ Set 2                       20 questions │
│ In progress                     Continue │
└──────────────────────────────────────────┘

┌──────────────────────────────────────────┐
│ Set 3                       20 questions │
│ Completed                                │
│                   Review  Practice again │
└──────────────────────────────────────────┘
```

Do not repeat College, Department, Level, and multiple audience chips unless needed to resolve real ambiguity.

---

# 10. Practice Set Lifecycle

Candidate-facing states are:

```text
Never attempted
→ Start

In progress
→ Continue

Submitted
→ Completed
→ Review
→ Practice again
```

`Practice again` creates a **new Attempt**.

It does not reopen or overwrite the submitted Attempt.

Previous Attempts remain preserved.

There is no arbitrary V1 retake limit while the Candidate has valid access.

Starting a new Attempt is available only when the Course Offering is active,
the Practice Set is active and published, the Candidate has a positive
server-side effective-access decision, and the Practice Set passes server-side
readiness/integrity checks.
Frontend state is explanatory, not authoritative access control.

---

# 11. Access Expiry

The server-side platform access policy supports:

```text
free           -> no individual Course Access Grant required
free_until     -> before cutoff no grant required; at/after cutoff an active grant is required
grant_required -> an active effective Course Access Grant is required
```

The `free_until` mode remains stored after its cutoff; no scheduler, Admin action
or policy mutation is required. An active individual Course Access Grant may
authorize a new Attempt after the cutoff.

The Candidate UI receives the effective result from the server. It must not
independently calculate authorization from policy mode, cutoff and grant data.

When effective access ends:

```text
new Practice Attempt
→ blocked
```

Previously submitted Attempts remain reviewable.

An Attempt validly started before Course Access expired or before a `free_until`
cutoff remains completable only until that Attempt's own authoritative deadline.

Expired courses do not need to remain permanently in the normal active `My courses` view. Historical Attempts can remain accessible through future Progress/history surfaces.

A currently in-progress Attempt must remain discoverable even if effective access
for new Attempts has ended.

---

# 12. Focused Practice Shell

Starting or continuing Practice leaves the normal Candidate shell.

```text
Candidate shell
      ↓
Start / Continue
      ↓
Focused Practice shell
      ↓
Submit
      ↓
Result Summary
      ↓
Focused Review
      ↓
Course / Home
```

During Practice:

- no mobile bottom navigation
- no Courses navigation
- no account menu
- no purchase prompts
- no unrelated app navigation

The student has one job.

---

# 13. CBT Practice

Flagging is part of V1.

Timed practice is required. The Course Offering supplies one practice duration
for all its Practice Sets; there are no per-set overrides in V1.

Each new Attempt receives a snapshotted duration and authoritative server
deadline. The visible countdown is presentation only. Refreshing, resuming,
changing the device clock or manipulating browser state must not extend the
deadline. Attempts created before timed practice must not receive invented
deadlines.

## Desktop

```text
┌─────────────────────────────────────────────────────┐
│ ← Exit       CSC 203 · Set 2      18:42   4 of 20 │
└─────────────────────────────────────────────────────┘

┌────────────────────────────────┐  ┌───────────────┐
│ Question 4                     │  │ Questions     │
│ ─────── progress ────────────  │  │               │
│                                │  │ 1 ✓  2 ✓  3 ○│
│ Question text...               │  │ 4 ●  5 ○  6 ⚑│
│                                │  │ ...           │
│ ○  A   Option                  │  │               │
│ ○  B   Option                  │  │               │
│ ○  C   Option                  │  └───────────────┘
│ ○  D   Option                  │
│                                │
│ Previous                 Next  │
│                                │
│ Flag question                  │
└────────────────────────────────┘
```

Desktop may use a persistent question rail because there is enough space.

## Mobile

```text
CSC 203 · Set 2       18:42      Exit

Question 4 of 20
──── progress ─────

Question text...

[ A  Option ]
[ B  Option ]
[ C  Option ]
[ D  Option ]

Previous                     Next

Questions              ⚑ Flag
```

`Questions` opens a bottom sheet.

---

# 14. Flag Behavior

Flagging means:

> I want to return to this question before finishing.

Flagging does **not** prevent submission.

Flag state should survive refresh and resume.

Because the current Attempt foundation does not yet include durable flag persistence, the Practice vertical slice will require a small backend/runtime extension.

The UI contract is already settled.

---

# 15. Question Navigator

The navigator is shared across CBT and Written.

States:

```text
Current
Answered
Unanswered
Flagged
```

Written may additionally represent explicitly skipped questions where useful.

States must not depend on colour alone.

Example language:

```text
✓ Answered
○ Unanswered
⚑ Flagged
● Current
```

Mobile question targets should remain comfortably tappable rather than compressing many tiny numbered controls.

---

# 16. CBT Persistence UX

Selecting an option should feel immediate.

```text
tap option
→ UI changes instantly
→ local cache updates
→ background server save
```

Normal successful saves should not interrupt the student with toasts.

Only meaningful problems become visible:

```text
Saving...
Couldn't save · Retry
Offline · answer kept on this device
Reconnecting...
```

Server state remains authoritative.

Local browser state is responsive cache/recovery, not permanent truth or authorization.

---

# 17. Written Practice

Written Practice uses the same visual family and focused shell as CBT.

```text
← Exit       SWE 205 · Set 1             3 of 10

────── progress ──────

Question 3

Explain ...


Your answer

┌─────────────────────────────────────────┐
│                                         │
│                                         │
│                                         │
└─────────────────────────────────────────┘

Saved

Skip this question


Previous                              Next
```

States:

```text
unanswered
answered
explicitly skipped
flagged
```

Blank text does not silently mean skipped.

`Skip this question` must be explicit.

Autosave status stays close enough to the answer field to remain understandable without dominating the screen.

---

# 18. Written Mobile Keyboard Behavior

This is part of acceptance, not later polish.

With an Android software keyboard open:

- the answer remains visible
- typing remains comfortable
- save status remains understandable
- navigation cannot become permanently hidden behind the keyboard
- layout must not blindly depend on `100vh`
- the Candidate should not need to close the keyboard after every answer just to proceed

This should be tested on a real Android device as well as responsive browser tooling.

---

# 19. Submission Confirmation

## CBT

```text
Submit practice set?

You answered 16 of 20 questions.
4 are unanswered and will be marked incorrect.

2 questions are flagged for review.

Keep practising              Submit
```

If everything is answered and unflagged, the copy naturally simplifies.

## Written

Written cannot submit until every question has one explicit state:

```text
answered
or
skipped
```

If incomplete:

```text
3 questions still need attention

Answer them or mark them as skipped before submitting.

View questions
```

The navigator helps locate them.

This completeness rule applies to a Candidate's manual submission. If the
server-authoritative timer expires first, the server submits the responses
already persisted and unresolved Written Questions remain timed-out/unanswered.
They must not be presented as Questions the Candidate chose to skip.

---

# 20. Result Summary

Submission never drops the Candidate directly into detailed Review.

## CBT

```text
Practice complete

16 / 20
80%

16 Correct
3 Incorrect
1 Unanswered


Review answers

Practice again
Back to course
```

`Review answers` is the dominant action.

## Written

No artificial score:

```text
Practice complete

8 answered
2 skipped
10 total

Compare your responses with the model answers.

Start review

Practice again
Back to course
```

When completion was caused by timeout, the summary must distinguish persisted
answers, explicit skips and timed-out/unanswered Questions. It must not count
timed-out Questions as skipped.

---

# 21. CBT Review

CBT Review uses the focused reader shell.

```text
← Results

CSC 203 · Set 2

Question 4 of 20                    Incorrect


Question text...


Your answer
B. ...


Correct answer
C. ...


Explanation
...


Reference
...


Previous                              Next
```

Desktop may include the question rail.

Mobile opens `Questions` as a bottom sheet.

Correctness always includes a text or symbol signal:

```text
Correct
Incorrect
Unanswered
```

Never rely only on green/red styling.

---

# 22. Written Review

Written Review defaults to one question at a time.

## Desktop

```text
Question 3 of 10

Question text...


┌──────────────────────┬──────────────────────┐
│ Your answer          │ Model answer         │
│                      │                      │
│ ...                  │ ...                  │
└──────────────────────┴──────────────────────┘


Key points
✓ ...
✓ ...
• ...


Reference
...


How well did you understand this?

Got it     Partially got it     Did not get it


Previous                                  Next
```

## Mobile

Candidate answer and Model answer stack vertically.

Self-assessment is optional.

The student may move to the next question without rating every question.

---

# 23. Dialog and Sheet Language

Shared overlay behavior is standardized before feature teams build their own.

| Interaction | Desktop | Mobile |
|---|---|---|
| Submit confirmation | Dialog | Dialog |
| Destructive confirmation | Dialog | Dialog |
| Question navigator | rail/panel or dialog | Bottom sheet |
| Course filters | popover/dialog | Bottom sheet |
| Future purchase/access selection | Dialog | Bottom sheet |
| Short temporary selection | Dialog | Sheet where appropriate |

Large workflows remain pages.

A Sheet is not a replacement for proper navigation.

---

# 24. Account

Candidate Account is calm and sectioned.

```text
Account

[AR] Abdulrahman
     email@example.com


Academic profile

College
Department
Level
Current semester

Edit academic profile


Course access
Manage access


Help & support
Get help


Sign out
```

The whole page should not permanently look like an edit form.

Read normally. Edit deliberately.

---

# 25. Support

Planned Candidate Support structure:

```text
Help and support

[ Search help... ]


Common questions

How do I get access to a course?
Why can't I start a practice set?
My granted access is missing or expired.
...


Send a request

Topic
Course if relevant
Title
Description

Submit


Your requests
...
```

This structure is informed by useful PromotionSure patterns but should be simplified and adapted for Summit.

Support does not need full implementation during the first Candidate vertical slice.

---

# 26. Landing Page

The public shell should be simpler than the Candidate shell.

```text
Summit Exam                       Log in   Get started
```

## Hero

```text
Prepare for your Summit exams
with organised practice.

Practise courses based on how they are actually examined,
whether CBT or written.

Get started        Log in
```

Then concise sections:

```text
Find your courses
Practise organised sets
Submit and review
```

Then:

- short CBT explanation
- short Written explanation
- access/pricing framing once pricing is finalized
- final CTA

A quiet disclosure should make clear that the platform is an independent exam-preparation service rather than an official university portal.

Do not use:

- fake testimonials
- fake user counts
- AI hype
- excessively long marketing pages

---

# 27. Auth and Onboarding

Auth and onboarding should share the product’s typography, colors, controls, spacing, and state patterns.

They do not use Candidate navigation.

Onboarding should feel like a short setup flow, not an administrative form.

Its purpose is to collect the academic context required for recommendations.

---

# 28. Loading, Empty, Error, and Network States

The Candidate UI uses one shared state vocabulary.

| State | Pattern |
|---|---|
| Loading | restrained skeleton matching expected content |
| Empty | short title + useful next action |
| Error | plain-language message + retry/action |
| Offline | persistent but quiet indicator |
| Saving | small inline state |
| Saved | subtle confirmation |
| Failed save | visible retry |
| Access required | clear locked state + action |
| Access expired | clear state without losing history |
| Session expired | clean path back to login |
| No search results | change/clear filters |
| No recommendations | Browse Courses |

Raw Supabase/Postgres errors never reach the Candidate UI.

---

# 29. Responsive Contract

Candidate UI acceptance includes at least:

```text
1440px desktop
800px tablet
390px phone
small-height Android phone
phone with virtual keyboard
```

Stress cases:

```text
long course title
long question
long answer
20–40 question navigator
no courses
many courses
slow network
offline
failed save
expired access
no search results
```

Mobile is a first-class composition, not compressed desktop.

---

# 30. Accessibility Contract

Candidate features inherit these requirements:

- clearly visible keyboard focus
- genuine semantic buttons and links
- useful input labels
- approximately 44px practical interactive targets
- state never communicated only by colour
- dialogs/sheets manage focus correctly
- CBT controls are keyboard navigable
- long text wraps safely
- reduced-motion preference is respected
- status changes are announced where appropriate without unnecessary ARIA noise

---

# 31. Candidate Component Language

Shared concepts the implementation should eventually expose:

```text
Foundation
Button
Input
Textarea
Select
Radio / Option
Checkbox
Dialog
Sheet
Skeleton
Status / Badge

Layout
PageContainer
PublicShell
AuthShell
CandidateShell
FocusedShell
SectionHeader

Shared states
LoadingState
EmptyState
ErrorState
NetworkStatus
SaveStatus

Candidate/domain
CourseCard
PracticeSetCard
PracticeHeader
QuestionOption
QuestionNavigator
FlagControl
ResultSummary
ReviewStatus
```

Do not build every domain component blindly during foundation work.

The first real vertical slice should prove and refine domain components against actual behavior and data.

---

# 32. Known Backend Gaps Exposed by the UI Contract

The UI design has intentionally surfaced several backend contracts that still need to exist before corresponding Candidate features are implemented.

| Desired UX | Current gap |
|---|---|
| Home `Continue practising` across courses | convenient Candidate-wide active-attempt query |
| Completed Practice Set / Review state | Practice Set Attempt/history summary contract |
| Durable flagging | flag persistence + authenticated RPC |
| Timed practice | duration/deadline snapshot and server-side expiry enforcement |
| Progress | not designed yet |
| Account/access history | later contract |
| Support | later contract |

These gaps do not invalidate the current foundation. They are precisely the kinds of implementation needs that should be discovered during design rather than after pages are already built.

---

# 33. Frozen Candidate Rules

Unless deliberately reopened, these are the Candidate defaults:

```text
Desktop top navigation
Mobile bottom navigation

Home + Courses initially
Progress added when worthwhile

Welcome back, not time-of-day greetings

Home:
Continue if applicable
Recommended for you
No Your Courses rail
No analytics-heavy dashboard

Courses:
one catalogue
profile-based defaults
search + filters
My courses as an access filter

Department + Level + current Semester control recommendation
Central effective access controls new-Attempt authorization

Focused Practice/Review shell

CBT:
flags
navigator
server-authoritative timer
unanswered allowed

Written:
explicit skip
autosave
all questions resolved before submit
timeout leaves unresolved questions timed-out/unanswered

Result Summary before detailed Review

Focused one-question-at-a-time Review

Written self-assessment optional

Retakes create new Attempts

Off-profile courses with effective access treated normally

Accessibility/mobile behavior are part of the foundation
```

---

# 34. Team Usage Rule

Once the shared UI foundation is implemented, Candidate feature work should happen **inside this system**.

Developers should not independently redefine:

- container widths
- primary navigation
- mobile bottom navigation
- typography hierarchy
- button hierarchy
- spacing scale
- border/radius treatment
- dialog behavior
- sheet behavior
- loading/error/empty states
- focus treatment
- network/save-state language

Feature-specific UI can evolve within the shared system. Shared rules should only change deliberately when implementation or user testing reveals a real reason.

The goal is that different developers can build separate Candidate features and the resulting application still feels like one product.

---

# 35. Next Design Step

Candidate UI is now sufficiently defined to move to the next shared-design task:

1. Design the Admin shell and Admin UI language using the same design foundation.
2. Reconcile Candidate + Admin shared primitives into `docs/UI_GUIDE.md`.
3. Define the exact shared-foundation implementation boundary.
4. Implement that foundation before major parallel UI development.
