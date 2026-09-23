begin;

create table public.content_sources (
  id uuid primary key default gen_random_uuid(),
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  source_type text not null check (
    source_type in (
      'lecturer_pdf',
      'lecture_material',
      'student_jotting',
      'past_question',
      'lecture_question',
      'manual',
      'ai_generated',
      'other'
    )
  ),
  title text not null check (btrim(title) <> ''),
  description text check (
    description is null or btrim(description) <> ''
  ),
  storage_path text check (
    storage_path is null or btrim(storage_path) <> ''
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint content_sources_id_course_offering_key
    unique (id, course_offering_id)
);

create table public.practice_sets (
  id uuid primary key default gen_random_uuid(),
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  title text not null check (btrim(title) <> ''),
  position integer not null check (position > 0),
  status text not null default 'draft' check (
    status in ('draft', 'review', 'published', 'archived')
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint practice_sets_course_offering_position_key
    unique (course_offering_id, position),
  constraint practice_sets_id_course_offering_key
    unique (id, course_offering_id)
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  question_text text not null check (btrim(question_text) <> ''),
  status text not null default 'draft' check (
    status in ('draft', 'review', 'published', 'archived')
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint questions_id_course_offering_key
    unique (id, course_offering_id)
);

create table public.practice_set_questions (
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  practice_set_id uuid not null,
  question_id uuid not null,
  position integer not null check (position > 0),
  primary key (practice_set_id, question_id),
  constraint practice_set_questions_set_position_key
    unique (practice_set_id, position),
  constraint practice_set_questions_set_offering_fkey
    foreign key (practice_set_id, course_offering_id)
    references public.practice_sets (id, course_offering_id)
    on delete restrict,
  constraint practice_set_questions_question_offering_fkey
    foreign key (question_id, course_offering_id)
    references public.questions (id, course_offering_id)
    on delete restrict
);

create table public.objective_question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete restrict,
  position smallint not null check (position > 0),
  option_text text not null check (btrim(option_text) <> ''),
  created_at timestamptz not null default now(),
  constraint objective_question_options_question_position_key
    unique (question_id, position),
  constraint objective_question_options_id_question_key
    unique (id, question_id)
);

create table public.objective_answer_keys (
  question_id uuid primary key references public.questions (id) on delete restrict,
  correct_option_id uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint objective_answer_keys_correct_option_question_fkey
    foreign key (correct_option_id, question_id)
    references public.objective_question_options (id, question_id)
    on delete restrict
);

create table public.question_review_content (
  question_id uuid primary key references public.questions (id) on delete restrict,
  explanation text check (
    explanation is null or btrim(explanation) <> ''
  ),
  reference_note text check (
    reference_note is null or btrim(reference_note) <> ''
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.written_answer_keys (
  question_id uuid primary key references public.questions (id) on delete restrict,
  model_answer text not null check (btrim(model_answer) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.written_key_points (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions (id) on delete restrict,
  position integer not null check (position > 0),
  point_text text not null check (btrim(point_text) <> ''),
  created_at timestamptz not null default now(),
  constraint written_key_points_question_position_key
    unique (question_id, position)
);

create table public.question_sources (
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  question_id uuid not null,
  content_source_id uuid not null,
  note text check (note is null or btrim(note) <> ''),
  created_at timestamptz not null default now(),
  primary key (question_id, content_source_id),
  constraint question_sources_question_offering_fkey
    foreign key (question_id, course_offering_id)
    references public.questions (id, course_offering_id)
    on delete restrict,
  constraint question_sources_source_offering_fkey
    foreign key (content_source_id, course_offering_id)
    references public.content_sources (id, course_offering_id)
    on delete restrict
);

create function public.validate_question_exam_mode()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  actual_exam_mode text;
  required_exam_mode text := tg_argv[0];
begin
  select course_offerings.exam_mode
  into actual_exam_mode
  from public.questions
  join public.course_offerings
    on course_offerings.id = questions.course_offering_id
  where questions.id = new.question_id
  for share of questions, course_offerings;

  if not found then
    raise exception 'Question % does not exist', new.question_id
      using errcode = '23503';
  end if;

  if actual_exam_mode <> required_exam_mode then
    raise exception 'Question % belongs to a % Course Offering; % content is not allowed',
      new.question_id,
      actual_exam_mode,
      required_exam_mode
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function public.validate_question_course_offering_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  new_exam_mode text;
begin
  if new.course_offering_id is not distinct from old.course_offering_id then
    return new;
  end if;

  select course_offerings.exam_mode
  into new_exam_mode
  from public.course_offerings
  where course_offerings.id = new.course_offering_id
  for share;

  if not found then
    raise exception 'Course Offering % does not exist', new.course_offering_id
      using errcode = '23503';
  end if;

  if new_exam_mode = 'cbt' and (
    exists (
      select 1
      from public.written_answer_keys
      where written_answer_keys.question_id = new.id
    )
    or exists (
      select 1
      from public.written_key_points
      where written_key_points.question_id = new.id
    )
  ) then
    raise exception 'Question % has Written content and cannot move to a CBT Course Offering', new.id
      using errcode = '23514';
  end if;

  if new_exam_mode = 'written' and (
    exists (
      select 1
      from public.objective_question_options
      where objective_question_options.question_id = new.id
    )
    or exists (
      select 1
      from public.objective_answer_keys
      where objective_answer_keys.question_id = new.id
    )
  ) then
    raise exception 'Question % has CBT content and cannot move to a Written Course Offering', new.id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create function public.validate_course_offering_exam_mode_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.exam_mode is not distinct from old.exam_mode then
    return new;
  end if;

  if new.exam_mode = 'cbt' and exists (
    select 1
    from public.questions
    where questions.course_offering_id = new.id
      and (
        exists (
          select 1
          from public.written_answer_keys
          where written_answer_keys.question_id = questions.id
        )
        or exists (
          select 1
          from public.written_key_points
          where written_key_points.question_id = questions.id
        )
      )
  ) then
    raise exception 'Course Offering % has Written content and cannot change to CBT', new.id
      using errcode = '23514';
  end if;

  if new.exam_mode = 'written' and exists (
    select 1
    from public.questions
    where questions.course_offering_id = new.id
      and (
        exists (
          select 1
          from public.objective_question_options
          where objective_question_options.question_id = questions.id
        )
        or exists (
          select 1
          from public.objective_answer_keys
          where objective_answer_keys.question_id = questions.id
        )
      )
  ) then
    raise exception 'Course Offering % has CBT content and cannot change to Written', new.id
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger validate_objective_question_options_exam_mode
before insert or update of question_id on public.objective_question_options
for each row
execute function public.validate_question_exam_mode('cbt');

create trigger validate_objective_answer_keys_exam_mode
before insert or update of question_id on public.objective_answer_keys
for each row
execute function public.validate_question_exam_mode('cbt');

create trigger validate_written_answer_keys_exam_mode
before insert or update of question_id on public.written_answer_keys
for each row
execute function public.validate_question_exam_mode('written');

create trigger validate_written_key_points_exam_mode
before insert or update of question_id on public.written_key_points
for each row
execute function public.validate_question_exam_mode('written');

create trigger validate_question_course_offering_change
before update of course_offering_id on public.questions
for each row
execute function public.validate_question_course_offering_change();

create trigger validate_course_offering_exam_mode_change
before update of exam_mode on public.course_offerings
for each row
execute function public.validate_course_offering_exam_mode_change();

create trigger set_content_sources_updated_at
before update on public.content_sources
for each row
execute function public.set_updated_at();

create trigger set_practice_sets_updated_at
before update on public.practice_sets
for each row
execute function public.set_updated_at();

create trigger set_questions_updated_at
before update on public.questions
for each row
execute function public.set_updated_at();

create trigger set_objective_answer_keys_updated_at
before update on public.objective_answer_keys
for each row
execute function public.set_updated_at();

create trigger set_question_review_content_updated_at
before update on public.question_review_content
for each row
execute function public.set_updated_at();

create trigger set_written_answer_keys_updated_at
before update on public.written_answer_keys
for each row
execute function public.set_updated_at();

create index content_sources_course_offering_id_idx
  on public.content_sources (course_offering_id);

create index questions_course_offering_id_idx
  on public.questions (course_offering_id);

alter table public.content_sources enable row level security;
alter table public.practice_sets enable row level security;
alter table public.questions enable row level security;
alter table public.practice_set_questions enable row level security;
alter table public.objective_question_options enable row level security;
alter table public.objective_answer_keys enable row level security;
alter table public.question_review_content enable row level security;
alter table public.written_answer_keys enable row level security;
alter table public.written_key_points enable row level security;
alter table public.question_sources enable row level security;

revoke all on table
  public.content_sources,
  public.practice_sets,
  public.questions,
  public.practice_set_questions,
  public.objective_question_options,
  public.objective_answer_keys,
  public.question_review_content,
  public.written_answer_keys,
  public.written_key_points,
  public.question_sources
from PUBLIC, anon, authenticated;

revoke all on function public.validate_question_exam_mode()
from PUBLIC, anon, authenticated;

revoke all on function public.validate_question_course_offering_change()
from PUBLIC, anon, authenticated;

revoke all on function public.validate_course_offering_exam_mode_change()
from PUBLIC, anon, authenticated;

commit;
