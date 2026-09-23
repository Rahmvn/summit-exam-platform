begin;

create table public.practice_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  practice_set_id uuid not null,
  exam_mode_snapshot text not null check (
    exam_mode_snapshot in ('cbt', 'written')
  ),
  practice_set_title_snapshot text not null check (
    btrim(practice_set_title_snapshot) <> ''
  ),
  status text not null default 'in_progress' check (
    status in ('in_progress', 'submitted')
  ),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint practice_attempts_status_submission_check check (
    (status = 'submitted' and submitted_at is not null)
    or (status = 'in_progress' and submitted_at is null)
  ),
  constraint practice_attempts_id_course_offering_key
    unique (id, course_offering_id),
  constraint practice_attempts_set_offering_fkey
    foreign key (practice_set_id, course_offering_id)
    references public.practice_sets (id, course_offering_id)
    on delete restrict
);

create table public.attempt_questions (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null,
  course_offering_id uuid not null,
  source_question_id uuid not null,
  position integer not null check (position > 0),
  question_text_snapshot text not null check (
    btrim(question_text_snapshot) <> ''
  ),
  created_at timestamptz not null default now(),
  constraint attempt_questions_attempt_position_key
    unique (attempt_id, position),
  constraint attempt_questions_attempt_source_question_key
    unique (attempt_id, source_question_id),
  constraint attempt_questions_id_source_question_key
    unique (id, source_question_id),
  constraint attempt_questions_attempt_offering_fkey
    foreign key (attempt_id, course_offering_id)
    references public.practice_attempts (id, course_offering_id)
    on delete cascade,
  constraint attempt_questions_source_question_offering_fkey
    foreign key (source_question_id, course_offering_id)
    references public.questions (id, course_offering_id)
    on delete restrict
);

create table public.attempt_objective_options (
  id uuid primary key default gen_random_uuid(),
  attempt_question_id uuid not null,
  source_question_id uuid not null,
  source_option_id uuid not null,
  position smallint not null check (position > 0),
  option_text_snapshot text not null check (
    btrim(option_text_snapshot) <> ''
  ),
  created_at timestamptz not null default now(),
  constraint attempt_objective_options_question_position_key
    unique (attempt_question_id, position),
  constraint attempt_objective_options_question_source_key
    unique (attempt_question_id, source_option_id),
  constraint attempt_objective_options_id_question_key
    unique (id, attempt_question_id),
  constraint attempt_objective_options_attempt_source_question_fkey
    foreign key (attempt_question_id, source_question_id)
    references public.attempt_questions (id, source_question_id)
    on delete cascade,
  constraint attempt_objective_options_source_option_question_fkey
    foreign key (source_option_id, source_question_id)
    references public.objective_question_options (id, question_id)
    on delete restrict
);

create table public.attempt_objective_answer_keys (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  correct_attempt_option_id uuid not null,
  created_at timestamptz not null default now(),
  constraint attempt_objective_answer_keys_option_question_fkey
    foreign key (correct_attempt_option_id, attempt_question_id)
    references public.attempt_objective_options (id, attempt_question_id)
    on delete cascade
);

create table public.attempt_review_content (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  explanation_snapshot text check (
    explanation_snapshot is null or btrim(explanation_snapshot) <> ''
  ),
  reference_note_snapshot text check (
    reference_note_snapshot is null or btrim(reference_note_snapshot) <> ''
  ),
  created_at timestamptz not null default now()
);

create table public.attempt_written_answer_keys (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  model_answer_snapshot text not null check (
    btrim(model_answer_snapshot) <> ''
  ),
  created_at timestamptz not null default now()
);

create table public.attempt_written_key_points (
  id uuid primary key default gen_random_uuid(),
  attempt_question_id uuid not null references public.attempt_questions (id) on delete cascade,
  position integer not null check (position > 0),
  point_text_snapshot text not null check (
    btrim(point_text_snapshot) <> ''
  ),
  created_at timestamptz not null default now(),
  constraint attempt_written_key_points_question_position_key
    unique (attempt_question_id, position)
);

create table public.objective_attempt_responses (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  selected_attempt_option_id uuid not null,
  answered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint objective_attempt_responses_option_question_fkey
    foreign key (selected_attempt_option_id, attempt_question_id)
    references public.attempt_objective_options (id, attempt_question_id)
    on delete cascade
);

create table public.written_attempt_responses (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  response_text text,
  is_skipped boolean not null default false,
  answered_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint written_attempt_responses_answer_state_check check (
    (is_skipped and response_text is null)
    or (
      not is_skipped
      and response_text is not null
      and btrim(response_text) <> ''
    )
  )
);

create table public.written_self_assessments (
  attempt_question_id uuid primary key references public.attempt_questions (id) on delete cascade,
  assessment text not null check (
    assessment in ('got_it', 'partially_got_it', 'did_not_get_it')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.objective_attempt_results (
  attempt_id uuid primary key references public.practice_attempts (id) on delete cascade,
  correct_count integer not null check (correct_count >= 0),
  total_questions integer not null check (total_questions > 0),
  score_percentage numeric(5, 2) not null check (
    score_percentage between 0 and 100
  ),
  created_at timestamptz not null default now(),
  constraint objective_attempt_results_count_check check (
    correct_count <= total_questions
  )
);

create function public.validate_practice_attempt_exam_mode()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  current_exam_mode text;
begin
  select course_offerings.exam_mode
  into current_exam_mode
  from public.course_offerings
  where course_offerings.id = new.course_offering_id
  for share;

  if not found then
    raise exception 'Course Offering % does not exist', new.course_offering_id
      using errcode = '23503';
  end if;

  if new.exam_mode_snapshot <> current_exam_mode then
    raise exception 'Attempt exam mode % does not match Course Offering exam mode %',
      new.exam_mode_snapshot,
      current_exam_mode
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function public.validate_attempt_question_exam_mode()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actual_exam_mode text;
  required_exam_mode text := tg_argv[0];
begin
  select practice_attempts.exam_mode_snapshot
  into actual_exam_mode
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = new.attempt_question_id
  for share of attempt_questions, practice_attempts;

  if not found then
    raise exception 'Attempt Question % does not exist', new.attempt_question_id
      using errcode = '23503';
  end if;

  if actual_exam_mode <> required_exam_mode then
    raise exception 'Attempt Question % belongs to a % Attempt; % data is not allowed',
      new.attempt_question_id,
      actual_exam_mode,
      required_exam_mode
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function public.validate_objective_attempt_result_exam_mode()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actual_exam_mode text;
begin
  select practice_attempts.exam_mode_snapshot
  into actual_exam_mode
  from public.practice_attempts
  where practice_attempts.id = new.attempt_id
  for share;

  if not found then
    raise exception 'Practice Attempt % does not exist', new.attempt_id
      using errcode = '23503';
  end if;

  if actual_exam_mode <> 'cbt' then
    raise exception 'Practice Attempt % is not a CBT Attempt', new.attempt_id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger validate_practice_attempt_exam_mode
before insert on public.practice_attempts
for each row
execute function public.validate_practice_attempt_exam_mode();

create trigger validate_attempt_objective_options_exam_mode
before insert or update of attempt_question_id on public.attempt_objective_options
for each row
execute function public.validate_attempt_question_exam_mode('cbt');

create trigger validate_attempt_objective_answer_keys_exam_mode
before insert or update of attempt_question_id on public.attempt_objective_answer_keys
for each row
execute function public.validate_attempt_question_exam_mode('cbt');

create trigger validate_objective_attempt_responses_exam_mode
before insert or update of attempt_question_id on public.objective_attempt_responses
for each row
execute function public.validate_attempt_question_exam_mode('cbt');

create trigger validate_attempt_written_answer_keys_exam_mode
before insert or update of attempt_question_id on public.attempt_written_answer_keys
for each row
execute function public.validate_attempt_question_exam_mode('written');

create trigger validate_attempt_written_key_points_exam_mode
before insert or update of attempt_question_id on public.attempt_written_key_points
for each row
execute function public.validate_attempt_question_exam_mode('written');

create trigger validate_written_attempt_responses_exam_mode
before insert or update of attempt_question_id on public.written_attempt_responses
for each row
execute function public.validate_attempt_question_exam_mode('written');

create trigger validate_written_self_assessments_exam_mode
before insert or update of attempt_question_id on public.written_self_assessments
for each row
execute function public.validate_attempt_question_exam_mode('written');

create trigger validate_objective_attempt_results_exam_mode
before insert or update of attempt_id on public.objective_attempt_results
for each row
execute function public.validate_objective_attempt_result_exam_mode();

create trigger set_practice_attempts_updated_at
before update on public.practice_attempts
for each row
execute function public.set_updated_at();

create trigger set_objective_attempt_responses_updated_at
before update on public.objective_attempt_responses
for each row
execute function public.set_updated_at();

create trigger set_written_attempt_responses_updated_at
before update on public.written_attempt_responses
for each row
execute function public.set_updated_at();

create trigger set_written_self_assessments_updated_at
before update on public.written_self_assessments
for each row
execute function public.set_updated_at();

create index practice_attempts_user_started_at_idx
  on public.practice_attempts (user_id, started_at desc);

create index practice_attempts_practice_set_started_at_idx
  on public.practice_attempts (practice_set_id, started_at desc);

alter table public.practice_attempts enable row level security;
alter table public.attempt_questions enable row level security;
alter table public.attempt_objective_options enable row level security;
alter table public.attempt_objective_answer_keys enable row level security;
alter table public.attempt_review_content enable row level security;
alter table public.attempt_written_answer_keys enable row level security;
alter table public.attempt_written_key_points enable row level security;
alter table public.objective_attempt_responses enable row level security;
alter table public.written_attempt_responses enable row level security;
alter table public.written_self_assessments enable row level security;
alter table public.objective_attempt_results enable row level security;

revoke all on table
  public.practice_attempts,
  public.attempt_questions,
  public.attempt_objective_options,
  public.attempt_objective_answer_keys,
  public.attempt_review_content,
  public.attempt_written_answer_keys,
  public.attempt_written_key_points,
  public.objective_attempt_responses,
  public.written_attempt_responses,
  public.written_self_assessments,
  public.objective_attempt_results
from PUBLIC, anon, authenticated;

revoke all on function public.validate_practice_attempt_exam_mode()
from PUBLIC, anon, authenticated;

revoke all on function public.validate_attempt_question_exam_mode()
from PUBLIC, anon, authenticated;

revoke all on function public.validate_objective_attempt_result_exam_mode()
from PUBLIC, anon, authenticated;

commit;
