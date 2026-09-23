begin;

alter table public.course_offerings
  add column expected_questions_per_practice_set integer,
  add column practice_duration_seconds integer,
  add constraint course_offerings_expected_questions_positive_check check (
    expected_questions_per_practice_set is null
    or expected_questions_per_practice_set > 0
  ),
  add constraint course_offerings_practice_duration_positive_check check (
    practice_duration_seconds is null
    or practice_duration_seconds > 0
  ),
  add constraint course_offerings_practice_configuration_pair_check check (
    (expected_questions_per_practice_set is null and practice_duration_seconds is null)
    or (
      expected_questions_per_practice_set is not null
      and practice_duration_seconds is not null
    )
  );

comment on column public.course_offerings.expected_questions_per_practice_set is
  'Nullable only for legacy/unconfigured Offerings during the staged rollout. Configure every Offering before a later migration makes this required.';

comment on column public.course_offerings.practice_duration_seconds is
  'Nullable only for legacy/unconfigured Offerings during the staged rollout. New configured Attempts snapshot this value.';

alter table public.practice_attempts
  add column duration_seconds_snapshot integer,
  add column expires_at timestamptz,
  add column submission_reason text,
  add constraint practice_attempts_duration_snapshot_positive_check check (
    duration_seconds_snapshot is null
    or duration_seconds_snapshot > 0
  ),
  add constraint practice_attempts_timing_pair_check check (
    (duration_seconds_snapshot is null and expires_at is null)
    or (duration_seconds_snapshot is not null and expires_at is not null)
  ),
  add constraint practice_attempts_deadline_consistent_check check (
    expires_at is null
    or expires_at = started_at
      + pg_catalog.make_interval(secs => duration_seconds_snapshot::double precision)
  ),
  add constraint practice_attempts_submission_reason_check check (
    submission_reason is null
    or submission_reason in ('manual', 'time_expired')
  ),
  add constraint practice_attempts_in_progress_reason_check check (
    status = 'submitted'
    or submission_reason is null
  ),
  add constraint practice_attempts_timeout_reason_check check (
    submission_reason <> 'time_expired'
    or (
      expires_at is not null
      and submitted_at is not null
      and submitted_at >= expires_at
    )
  );

comment on column public.practice_attempts.duration_seconds_snapshot is
  'Frozen Offering duration for a configured Attempt. Null only for legacy Attempts and new Attempts on legacy/unconfigured Offerings during the staged rollout.';

comment on column public.practice_attempts.expires_at is
  'Authoritative server deadline for a configured Attempt. Legacy Attempts retain null rather than receiving an invented deadline.';

comment on column public.practice_attempts.submission_reason is
  'Terminal reason for new submissions. Null remains valid only for Attempts submitted before this column existed.';

create index practice_attempts_in_progress_expiry_idx
  on public.practice_attempts (expires_at)
  where status = 'in_progress' and expires_at is not null;

create table public.platform_access_policy (
  singleton_key boolean primary key default true check (singleton_key),
  policy_mode text not null check (
    policy_mode in ('free', 'free_until', 'grant_required')
  ),
  free_until_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_access_policy_cutoff_check check (
    (policy_mode = 'free_until' and free_until_at is not null)
    or (policy_mode in ('free', 'grant_required') and free_until_at is null)
  )
);

comment on table public.platform_access_policy is
  'Singleton platform-wide Candidate access policy. A free_until row remains free_until after cutoff; runtime evaluation then requires an active Offering grant.';

insert into public.platform_access_policy (
  singleton_key,
  policy_mode,
  free_until_at
)
values (
  true,
  'grant_required',
  null
);

create trigger set_platform_access_policy_updated_at
before update on public.platform_access_policy
for each row
execute function public.set_updated_at();

alter table public.platform_access_policy enable row level security;

revoke all on table public.platform_access_policy
from PUBLIC, anon, authenticated;

create function public.resolve_effective_course_access(
  p_course_offering_id uuid
)
returns table (
  has_effective_access boolean,
  access_basis text,
  effective_access_expires_at timestamptz,
  policy_mode text,
  free_until_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_policy_mode text;
  v_free_until_at timestamptz;
  v_grant_expires_at timestamptz;
  v_now timestamptz := pg_catalog.now();
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.course_offerings
    where course_offerings.id = p_course_offering_id
  ) then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;

  select
    platform_access_policy.policy_mode,
    platform_access_policy.free_until_at
  into
    v_policy_mode,
    v_free_until_at
  from public.platform_access_policy
  where platform_access_policy.singleton_key;

  if not found then
    raise exception 'Platform access policy is not configured'
      using errcode = '55000';
  end if;

  select max(course_access_grants.expires_at)
  into v_grant_expires_at
  from public.course_access_grants
  where course_access_grants.user_id = v_user_id
    and course_access_grants.course_offering_id = p_course_offering_id
    and course_access_grants.revoked_at is null
    and course_access_grants.starts_at <= v_now
    and course_access_grants.expires_at > v_now;

  if v_policy_mode = 'free' then
    return query select true, 'platform_free'::text, null::timestamptz,
      v_policy_mode, v_free_until_at;
  elsif v_policy_mode = 'free_until' and v_now < v_free_until_at then
    return query select true, 'free_period'::text,
      v_free_until_at,
      v_policy_mode, v_free_until_at;
  elsif v_grant_expires_at is not null then
    return query select true, 'course_access_grant'::text,
      v_grant_expires_at, v_policy_mode, v_free_until_at;
  else
    return query select false, null::text, null::timestamptz,
      v_policy_mode, v_free_until_at;
  end if;
end;
$$;

revoke all on function public.resolve_effective_course_access(uuid)
from PUBLIC, anon, authenticated;

grant execute on function public.resolve_effective_course_access(uuid)
to authenticated;

create function public.finalize_expired_practice_attempt(
  p_attempt_id uuid
)
returns public.practice_attempts
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.practice_attempts%rowtype;
  v_now timestamptz;
  v_total_questions integer;
  v_correct_count integer;
  v_score_percentage numeric(5, 2);
begin
  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.id = p_attempt_id
  for update;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  v_now := pg_catalog.clock_timestamp();

  if v_attempt.status <> 'in_progress'
     or v_attempt.expires_at is null
     or v_now < v_attempt.expires_at then
    return v_attempt;
  end if;

  select count(*)::integer
  into v_total_questions
  from public.attempt_questions
  where attempt_questions.attempt_id = v_attempt.id;

  if v_total_questions = 0 then
    raise exception 'The Attempt does not contain any frozen Questions'
      using errcode = '23514';
  end if;

  if v_attempt.exam_mode_snapshot = 'cbt' then
    if (
      select count(*)
      from public.attempt_objective_answer_keys
      join public.attempt_questions
        on attempt_questions.id = attempt_objective_answer_keys.attempt_question_id
      where attempt_questions.attempt_id = v_attempt.id
    ) <> v_total_questions then
      raise exception 'The frozen CBT answer keys are incomplete'
        using errcode = '23514';
    end if;

    select count(*) filter (
      where objective_attempt_responses.selected_attempt_option_id
        = attempt_objective_answer_keys.correct_attempt_option_id
    )::integer
    into v_correct_count
    from public.attempt_questions
    join public.attempt_objective_answer_keys
      on attempt_objective_answer_keys.attempt_question_id = attempt_questions.id
    left join public.objective_attempt_responses
      on objective_attempt_responses.attempt_question_id = attempt_questions.id
    where attempt_questions.attempt_id = v_attempt.id;

    v_score_percentage := pg_catalog.round(
      (v_correct_count::numeric * 100.0) / v_total_questions::numeric,
      2
    );

    insert into public.objective_attempt_results (
      attempt_id,
      correct_count,
      total_questions,
      score_percentage
    )
    values (
      v_attempt.id,
      v_correct_count,
      v_total_questions,
      v_score_percentage
    )
    on conflict (attempt_id) do update
    set correct_count = excluded.correct_count,
        total_questions = excluded.total_questions,
        score_percentage = excluded.score_percentage;
  end if;

  update public.practice_attempts
  set status = 'submitted',
      submitted_at = v_now,
      submission_reason = 'time_expired'
  where practice_attempts.id = v_attempt.id
    and practice_attempts.status = 'in_progress'
  returning * into v_attempt;

  return v_attempt;
end;
$$;

revoke all on function public.finalize_expired_practice_attempt(uuid)
from PUBLIC, anon, authenticated;

alter function public.get_practice_attempt_state(uuid)
rename to get_practice_attempt_state_without_deadline_legacy;

alter function public.save_objective_attempt_response(uuid, uuid)
rename to save_objective_attempt_response_without_deadline_legacy;

alter function public.clear_objective_attempt_response(uuid)
rename to clear_objective_attempt_response_without_deadline_legacy;

alter function public.save_written_attempt_response(uuid, text, boolean)
rename to save_written_attempt_response_without_deadline_legacy;

alter function public.clear_written_attempt_response(uuid)
rename to clear_written_attempt_response_without_deadline_legacy;

alter function public.submit_practice_attempt(uuid)
rename to submit_practice_attempt_without_deadline_legacy;

alter function public.get_practice_attempt_review(uuid)
rename to get_practice_attempt_review_without_deadline_legacy;

alter function public.save_written_self_assessment(uuid, text)
rename to save_written_self_assessment_without_deadline_legacy;

revoke all on function public.get_practice_attempt_state_without_deadline_legacy(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_objective_attempt_response_without_deadline_legacy(uuid, uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.clear_objective_attempt_response_without_deadline_legacy(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_written_attempt_response_without_deadline_legacy(uuid, text, boolean)
from PUBLIC, anon, authenticated;

revoke all on function public.clear_written_attempt_response_without_deadline_legacy(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.submit_practice_attempt_without_deadline_legacy(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.get_practice_attempt_review_without_deadline_legacy(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_written_self_assessment_without_deadline_legacy(uuid, text)
from PUBLIC, anon, authenticated;

create function public.get_practice_attempt_state(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
  v_state jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.id = p_attempt_id
    and practice_attempts.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  v_state := public.get_practice_attempt_state_without_deadline_legacy(v_attempt.id);

  return v_state || jsonb_build_object(
    'duration_seconds', v_attempt.duration_seconds_snapshot,
    'expires_at', v_attempt.expires_at,
    'submission_reason', v_attempt.submission_reason,
    'server_now', pg_catalog.clock_timestamp()
  );
end;
$$;

create function public.attempt_timeout_mutation_result(
  p_attempt public.practice_attempts,
  p_attempt_question_id uuid
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'attempt_id', p_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'status', p_attempt.status,
    'state', 'time_expired',
    'submitted_at', p_attempt.submitted_at,
    'submission_reason', p_attempt.submission_reason
  );
$$;

revoke all on function public.attempt_timeout_mutation_result(public.practice_attempts, uuid)
from PUBLIC, anon, authenticated;

create function public.save_objective_attempt_response(
  p_attempt_question_id uuid,
  p_selected_attempt_option_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = p_attempt_question_id
    and practice_attempts.user_id = v_user_id
  for update of practice_attempts;

  if not found then
    raise exception 'Attempt Question % was not found', p_attempt_question_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  if v_attempt.status = 'submitted'
     and v_attempt.submission_reason = 'time_expired' then
    return public.attempt_timeout_mutation_result(v_attempt, p_attempt_question_id);
  end if;

  return public.save_objective_attempt_response_without_deadline_legacy(
    p_attempt_question_id,
    p_selected_attempt_option_id
  );
end;
$$;

create function public.clear_objective_attempt_response(
  p_attempt_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = p_attempt_question_id
    and practice_attempts.user_id = v_user_id
  for update of practice_attempts;

  if not found then
    raise exception 'Attempt Question % was not found', p_attempt_question_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  if v_attempt.status = 'submitted'
     and v_attempt.submission_reason = 'time_expired' then
    return public.attempt_timeout_mutation_result(v_attempt, p_attempt_question_id);
  end if;

  return public.clear_objective_attempt_response_without_deadline_legacy(
    p_attempt_question_id
  );
end;
$$;

create function public.save_written_attempt_response(
  p_attempt_question_id uuid,
  p_response_text text,
  p_is_skipped boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = p_attempt_question_id
    and practice_attempts.user_id = v_user_id
  for update of practice_attempts;

  if not found then
    raise exception 'Attempt Question % was not found', p_attempt_question_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  if v_attempt.status = 'submitted'
     and v_attempt.submission_reason = 'time_expired' then
    return public.attempt_timeout_mutation_result(v_attempt, p_attempt_question_id);
  end if;

  return public.save_written_attempt_response_without_deadline_legacy(
    p_attempt_question_id,
    p_response_text,
    p_is_skipped
  );
end;
$$;

create function public.clear_written_attempt_response(
  p_attempt_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = p_attempt_question_id
    and practice_attempts.user_id = v_user_id
  for update of practice_attempts;

  if not found then
    raise exception 'Attempt Question % was not found', p_attempt_question_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  if v_attempt.status = 'submitted'
     and v_attempt.submission_reason = 'time_expired' then
    return public.attempt_timeout_mutation_result(v_attempt, p_attempt_question_id);
  end if;

  return public.clear_written_attempt_response_without_deadline_legacy(
    p_attempt_question_id
  );
end;
$$;

create function public.submit_practice_attempt(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
  v_result jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.id = p_attempt_id
    and practice_attempts.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  v_result := public.submit_practice_attempt_without_deadline_legacy(v_attempt.id);

  if v_attempt.status = 'in_progress' then
    update public.practice_attempts
    set submission_reason = 'manual'
    where practice_attempts.id = v_attempt.id
    returning * into v_attempt;
  else
    select practice_attempts.*
    into v_attempt
    from public.practice_attempts
    where practice_attempts.id = v_attempt.id;
  end if;

  return v_result || jsonb_build_object(
    'duration_seconds', v_attempt.duration_seconds_snapshot,
    'expires_at', v_attempt.expires_at,
    'submission_reason', v_attempt.submission_reason
  );
end;
$$;

create function public.save_written_self_assessment(
  p_attempt_question_id uuid,
  p_assessment text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.attempt_questions
  join public.practice_attempts
    on practice_attempts.id = attempt_questions.attempt_id
  where attempt_questions.id = p_attempt_question_id
    and practice_attempts.user_id = v_user_id
  for update of practice_attempts;

  if not found then
    raise exception 'Attempt Question % was not found', p_attempt_question_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  return public.save_written_self_assessment_without_deadline_legacy(
    p_attempt_question_id,
    p_assessment
  );
end;
$$;

create or replace function public.start_practice_attempt(p_practice_set_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
  v_attempt_id uuid;
  v_course_offering_id uuid;
  v_practice_set_title text;
  v_exam_mode text;
  v_practice_set_status text;
  v_practice_set_is_active boolean;
  v_course_offering_is_active boolean;
  v_expected_question_count integer;
  v_duration_seconds integer;
  v_has_effective_access boolean;
  v_question_count integer;
  v_snapshot_question_count integer;
  v_started_at timestamptz;
  v_expires_at timestamptz;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_user_id::text || ':' || p_practice_set_id::text,
      0
    )
  );

  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.user_id = v_user_id
    and practice_attempts.practice_set_id = p_practice_set_id
    and practice_attempts.status = 'in_progress'
  for update;

  if found then
    select *
    into v_attempt
    from public.finalize_expired_practice_attempt(v_attempt.id);

    return public.get_practice_attempt_state(v_attempt.id);
  end if;

  select
    practice_sets.course_offering_id,
    practice_sets.title,
    practice_sets.status,
    practice_sets.is_active,
    course_offerings.exam_mode,
    course_offerings.is_active,
    course_offerings.expected_questions_per_practice_set,
    course_offerings.practice_duration_seconds
  into
    v_course_offering_id,
    v_practice_set_title,
    v_practice_set_status,
    v_practice_set_is_active,
    v_exam_mode,
    v_course_offering_is_active,
    v_expected_question_count,
    v_duration_seconds
  from public.practice_sets
  join public.course_offerings
    on course_offerings.id = practice_sets.course_offering_id
  where practice_sets.id = p_practice_set_id
  for share of practice_sets, course_offerings;

  if not found then
    raise exception 'Practice Set % was not found', p_practice_set_id
      using errcode = 'P0002';
  end if;

  if v_practice_set_status <> 'published' or not v_practice_set_is_active then
    raise exception 'This Practice Set is not available for a new Attempt'
      using errcode = '55000';
  end if;

  if not v_course_offering_is_active then
    raise exception 'This Course Offering is not active'
      using errcode = '55000';
  end if;

  select effective_access.has_effective_access
  into v_has_effective_access
  from public.resolve_effective_course_access(v_course_offering_id) as effective_access;

  if not coalesce(v_has_effective_access, false) then
    raise exception 'Effective Course Access is required to start a new Attempt'
      using errcode = '42501';
  end if;

  perform 1
  from public.practice_set_questions
  join public.questions
    on questions.id = practice_set_questions.question_id
  where practice_set_questions.practice_set_id = p_practice_set_id
  order by practice_set_questions.position
  for share of practice_set_questions, questions;

  select count(*)::integer
  into v_question_count
  from public.practice_set_questions
  where practice_set_questions.practice_set_id = p_practice_set_id;

  if v_question_count = 0 then
    raise exception 'The published Practice Set does not contain any Questions'
      using errcode = '23514';
  end if;

  if v_expected_question_count is not null
     and v_question_count <> v_expected_question_count then
    raise exception 'The Practice Set contains % Questions; this Offering requires exactly %',
      v_question_count,
      v_expected_question_count
      using errcode = '23514';
  end if;

  if (
    select min(practice_set_questions.position) <> 1
      or max(practice_set_questions.position) <> v_question_count
    from public.practice_set_questions
    where practice_set_questions.practice_set_id = p_practice_set_id
  ) then
    raise exception 'Practice Set Question positions must be contiguous from 1'
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from public.practice_set_questions
    join public.questions
      on questions.id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
      and (
        practice_set_questions.course_offering_id <> v_course_offering_id
        or questions.course_offering_id <> v_course_offering_id
        or not questions.is_active
      )
  ) then
    raise exception 'Every Question must be active and belong to the Practice Set Course Offering'
      using errcode = '23514';
  end if;

  if v_exam_mode = 'cbt' then
    perform 1
    from public.practice_set_questions
    join public.objective_question_options
      on objective_question_options.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
    order by practice_set_questions.position, objective_question_options.position
    for share of objective_question_options;

    perform 1
    from public.practice_set_questions
    join public.objective_answer_keys
      on objective_answer_keys.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
    for share of objective_answer_keys;

    if exists (
      select 1
      from public.practice_set_questions
      where practice_set_questions.practice_set_id = p_practice_set_id
        and (
          select count(*)
          from public.objective_question_options
          where objective_question_options.question_id = practice_set_questions.question_id
        ) < 2
    ) then
      raise exception 'Every CBT Question must have at least two options'
        using errcode = '23514';
    end if;

    if exists (
      select 1
      from public.practice_set_questions
      left join public.objective_answer_keys
        on objective_answer_keys.question_id = practice_set_questions.question_id
      where practice_set_questions.practice_set_id = p_practice_set_id
        and objective_answer_keys.question_id is null
    ) then
      raise exception 'Every CBT Question must have an answer key'
        using errcode = '23514';
    end if;

    if exists (
      select 1
      from public.practice_set_questions
      join public.objective_answer_keys
        on objective_answer_keys.question_id = practice_set_questions.question_id
      where practice_set_questions.practice_set_id = p_practice_set_id
        and not exists (
          select 1
          from public.objective_question_options
          where objective_question_options.id = objective_answer_keys.correct_option_id
            and objective_question_options.question_id = practice_set_questions.question_id
        )
    ) then
      raise exception 'Every CBT answer key must reference an option from its Question'
        using errcode = '23514';
    end if;
  else
    perform 1
    from public.practice_set_questions
    join public.written_answer_keys
      on written_answer_keys.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
    for share of written_answer_keys;

    perform 1
    from public.practice_set_questions
    join public.written_key_points
      on written_key_points.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
    order by practice_set_questions.position, written_key_points.position
    for share of written_key_points;

    if exists (
      select 1
      from public.practice_set_questions
      left join public.written_answer_keys
        on written_answer_keys.question_id = practice_set_questions.question_id
      where practice_set_questions.practice_set_id = p_practice_set_id
        and (
          written_answer_keys.question_id is null
          or pg_catalog.btrim(written_answer_keys.model_answer) = ''
        )
    ) then
      raise exception 'Every Written Question must have a nonblank model answer'
        using errcode = '23514';
    end if;

    if exists (
      select 1
      from public.practice_set_questions
      where practice_set_questions.practice_set_id = p_practice_set_id
        and not exists (
          select 1
          from public.written_key_points
          where written_key_points.question_id = practice_set_questions.question_id
        )
    ) then
      raise exception 'Every Written Question must have at least one key point'
        using errcode = '23514';
    end if;
  end if;

  perform 1
  from public.practice_set_questions
  join public.question_review_content
    on question_review_content.question_id = practice_set_questions.question_id
  where practice_set_questions.practice_set_id = p_practice_set_id
  for share of question_review_content;

  v_started_at := pg_catalog.clock_timestamp();
  if v_duration_seconds is not null then
    v_expires_at := v_started_at
      + pg_catalog.make_interval(secs => v_duration_seconds::double precision);
  end if;

  insert into public.practice_attempts (
    user_id,
    course_offering_id,
    practice_set_id,
    exam_mode_snapshot,
    practice_set_title_snapshot,
    started_at,
    duration_seconds_snapshot,
    expires_at
  )
  values (
    v_user_id,
    v_course_offering_id,
    p_practice_set_id,
    v_exam_mode,
    v_practice_set_title,
    v_started_at,
    v_duration_seconds,
    v_expires_at
  )
  returning id into v_attempt_id;

  insert into public.attempt_questions (
    attempt_id,
    course_offering_id,
    source_question_id,
    position,
    question_text_snapshot
  )
  select
    v_attempt_id,
    v_course_offering_id,
    questions.id,
    practice_set_questions.position,
    questions.question_text
  from public.practice_set_questions
  join public.questions
    on questions.id = practice_set_questions.question_id
  where practice_set_questions.practice_set_id = p_practice_set_id
  order by practice_set_questions.position;

  get diagnostics v_snapshot_question_count = row_count;

  if v_snapshot_question_count <> v_question_count then
    raise exception 'The Practice Set changed while the Attempt was being created'
      using errcode = '40001';
  end if;

  insert into public.attempt_review_content (
    attempt_question_id,
    explanation_snapshot,
    reference_note_snapshot
  )
  select
    attempt_questions.id,
    question_review_content.explanation,
    question_review_content.reference_note
  from public.attempt_questions
  join public.question_review_content
    on question_review_content.question_id = attempt_questions.source_question_id
  where attempt_questions.attempt_id = v_attempt_id;

  if v_exam_mode = 'cbt' then
    insert into public.attempt_objective_options (
      attempt_question_id,
      source_question_id,
      source_option_id,
      position,
      option_text_snapshot
    )
    select
      attempt_questions.id,
      attempt_questions.source_question_id,
      objective_question_options.id,
      objective_question_options.position,
      objective_question_options.option_text
    from public.attempt_questions
    join public.objective_question_options
      on objective_question_options.question_id = attempt_questions.source_question_id
    where attempt_questions.attempt_id = v_attempt_id
    order by attempt_questions.position, objective_question_options.position;

    insert into public.attempt_objective_answer_keys (
      attempt_question_id,
      correct_attempt_option_id
    )
    select
      attempt_questions.id,
      attempt_objective_options.id
    from public.attempt_questions
    join public.objective_answer_keys
      on objective_answer_keys.question_id = attempt_questions.source_question_id
    join public.attempt_objective_options
      on attempt_objective_options.attempt_question_id = attempt_questions.id
      and attempt_objective_options.source_option_id = objective_answer_keys.correct_option_id
    where attempt_questions.attempt_id = v_attempt_id;

    if exists (
      select 1
      from public.attempt_questions
      where attempt_questions.attempt_id = v_attempt_id
        and (
          select count(*)
          from public.attempt_objective_options
          where attempt_objective_options.attempt_question_id = attempt_questions.id
        ) < 2
    ) or (
      select count(*)
      from public.attempt_objective_answer_keys
      join public.attempt_questions
        on attempt_questions.id = attempt_objective_answer_keys.attempt_question_id
      where attempt_questions.attempt_id = v_attempt_id
    ) <> v_question_count then
      raise exception 'The CBT snapshot is incomplete'
        using errcode = '23514';
    end if;
  else
    insert into public.attempt_written_answer_keys (
      attempt_question_id,
      model_answer_snapshot
    )
    select
      attempt_questions.id,
      written_answer_keys.model_answer
    from public.attempt_questions
    join public.written_answer_keys
      on written_answer_keys.question_id = attempt_questions.source_question_id
    where attempt_questions.attempt_id = v_attempt_id;

    insert into public.attempt_written_key_points (
      attempt_question_id,
      position,
      point_text_snapshot
    )
    select
      attempt_questions.id,
      written_key_points.position,
      written_key_points.point_text
    from public.attempt_questions
    join public.written_key_points
      on written_key_points.question_id = attempt_questions.source_question_id
    where attempt_questions.attempt_id = v_attempt_id
    order by attempt_questions.position, written_key_points.position;

    if (
      select count(*)
      from public.attempt_written_answer_keys
      join public.attempt_questions
        on attempt_questions.id = attempt_written_answer_keys.attempt_question_id
      where attempt_questions.attempt_id = v_attempt_id
    ) <> v_question_count or exists (
      select 1
      from public.attempt_questions
      where attempt_questions.attempt_id = v_attempt_id
        and not exists (
          select 1
          from public.attempt_written_key_points
          where attempt_written_key_points.attempt_question_id = attempt_questions.id
        )
    ) then
      raise exception 'The Written snapshot is incomplete'
        using errcode = '23514';
    end if;
  end if;

  return public.get_practice_attempt_state(v_attempt_id);
end;
$$;

create function public.get_practice_attempt_review(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
  v_review jsonb;
  v_questions jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.id = p_attempt_id
    and practice_attempts.user_id = v_user_id
  for update;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  select *
  into v_attempt
  from public.finalize_expired_practice_attempt(v_attempt.id);

  v_review := public.get_practice_attempt_review_without_deadline_legacy(
    v_attempt.id
  );

  if v_attempt.exam_mode_snapshot = 'written'
     and v_attempt.submission_reason = 'time_expired' then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'attempt_question_id', attempt_questions.id,
          'position', attempt_questions.position,
          'question_text', attempt_questions.question_text_snapshot,
          'response_text', written_attempt_responses.response_text,
          'is_skipped', written_attempt_responses.is_skipped,
          'response_state', case
            when written_attempt_responses.attempt_question_id is null
              then 'timed_out_unanswered'
            when written_attempt_responses.is_skipped then 'skipped'
            else 'answered'
          end,
          'model_answer', attempt_written_answer_keys.model_answer_snapshot,
          'key_points', (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'position', attempt_written_key_points.position,
                  'point_text', attempt_written_key_points.point_text_snapshot
                ) order by attempt_written_key_points.position
              ),
              '[]'::jsonb
            )
            from public.attempt_written_key_points
            where attempt_written_key_points.attempt_question_id = attempt_questions.id
          ),
          'explanation', attempt_review_content.explanation_snapshot,
          'reference_note', attempt_review_content.reference_note_snapshot,
          'self_assessment', written_self_assessments.assessment
        ) order by attempt_questions.position
      ),
      '[]'::jsonb
    )
    into v_questions
    from public.attempt_questions
    join public.attempt_written_answer_keys
      on attempt_written_answer_keys.attempt_question_id = attempt_questions.id
    left join public.written_attempt_responses
      on written_attempt_responses.attempt_question_id = attempt_questions.id
    left join public.attempt_review_content
      on attempt_review_content.attempt_question_id = attempt_questions.id
    left join public.written_self_assessments
      on written_self_assessments.attempt_question_id = attempt_questions.id
    where attempt_questions.attempt_id = v_attempt.id;

    v_review := jsonb_set(v_review, '{questions}', v_questions, true);
  end if;

  return v_review || jsonb_build_object(
    'duration_seconds', v_attempt.duration_seconds_snapshot,
    'expires_at', v_attempt.expires_at,
    'submission_reason', v_attempt.submission_reason
  );
end;
$$;

alter function public.get_candidate_course_overview()
rename to get_candidate_course_overview_grant_only_legacy;

alter function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
rename to browse_course_offerings_grant_only_legacy;

alter function public.get_candidate_course_offering_detail(uuid)
rename to get_candidate_course_offering_detail_grant_only_legacy;

revoke all on function public.get_candidate_course_overview_grant_only_legacy()
from PUBLIC, anon, authenticated;

revoke all on function public.browse_course_offerings_grant_only_legacy(uuid, uuid, uuid, uuid, text)
from PUBLIC, anon, authenticated;

revoke all on function public.get_candidate_course_offering_detail_grant_only_legacy(uuid)
from PUBLIC, anon, authenticated;

create function public.add_effective_access_to_course_payload(p_payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_effective_access record;
begin
  select *
  into v_effective_access
  from public.resolve_effective_course_access(
    (p_payload ->> 'course_offering_id')::uuid
  );

  return (p_payload - 'has_active_access' - 'access_expires_at')
    || jsonb_build_object(
      'has_effective_access', v_effective_access.has_effective_access,
      'effective_access_basis', v_effective_access.access_basis,
      'effective_access_expires_at', v_effective_access.effective_access_expires_at,
      'access_policy_mode', v_effective_access.policy_mode,
      'free_until_at', v_effective_access.free_until_at
    );
end;
$$;

revoke all on function public.add_effective_access_to_course_payload(jsonb)
from PUBLIC, anon, authenticated;

create function public.get_candidate_course_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_legacy jsonb;
  v_your_courses jsonb;
  v_relevant_courses jsonb;
begin
  v_legacy := public.get_candidate_course_overview_grant_only_legacy();

  select coalesce(
    jsonb_agg(public.add_effective_access_to_course_payload(item) order by ordinal),
    '[]'::jsonb
  )
  into v_your_courses
  from jsonb_array_elements(v_legacy -> 'your_courses')
    with ordinality as rows(item, ordinal);

  select coalesce(
    jsonb_agg(public.add_effective_access_to_course_payload(item) order by ordinal),
    '[]'::jsonb
  )
  into v_relevant_courses
  from jsonb_array_elements(v_legacy -> 'relevant_courses')
    with ordinality as rows(item, ordinal);

  return jsonb_build_object(
    'your_courses', v_your_courses,
    'relevant_courses', v_relevant_courses
  );
end;
$$;

create function public.browse_course_offerings(
  p_college_id uuid default null,
  p_department_id uuid default null,
  p_level_id uuid default null,
  p_semester_id uuid default null,
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_legacy jsonb;
  v_course_offerings jsonb;
begin
  v_legacy := public.browse_course_offerings_grant_only_legacy(
    p_college_id,
    p_department_id,
    p_level_id,
    p_semester_id,
    p_search
  );

  select coalesce(
    jsonb_agg(public.add_effective_access_to_course_payload(item) order by ordinal),
    '[]'::jsonb
  )
  into v_course_offerings
  from jsonb_array_elements(v_legacy)
    with ordinality as rows(item, ordinal);

  return v_course_offerings;
end;
$$;

create function public.get_candidate_course_offering_detail(
  p_course_offering_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt_id uuid;
  v_detail jsonb;
  v_expected_question_count integer;
  v_practice_duration_seconds integer;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  for v_attempt_id in
    select practice_attempts.id
    from public.practice_attempts
    where practice_attempts.user_id = v_user_id
      and practice_attempts.course_offering_id = p_course_offering_id
      and practice_attempts.status = 'in_progress'
      and practice_attempts.expires_at is not null
      and practice_attempts.expires_at <= pg_catalog.clock_timestamp()
    order by practice_attempts.expires_at, practice_attempts.id
  loop
    perform public.finalize_expired_practice_attempt(v_attempt_id);
  end loop;

  v_detail := public.get_candidate_course_offering_detail_grant_only_legacy(
    p_course_offering_id
  );

  select
    course_offerings.expected_questions_per_practice_set,
    course_offerings.practice_duration_seconds
  into
    v_expected_question_count,
    v_practice_duration_seconds
  from public.course_offerings
  where course_offerings.id = p_course_offering_id;

  return public.add_effective_access_to_course_payload(v_detail)
    || jsonb_build_object(
      'expected_questions_per_practice_set', v_expected_question_count,
      'practice_duration_seconds', v_practice_duration_seconds
    );
end;
$$;

alter table public.questions
  drop column status;

revoke all on function public.get_practice_attempt_state(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.start_practice_attempt(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_objective_attempt_response(uuid, uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.clear_objective_attempt_response(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_written_attempt_response(uuid, text, boolean)
from PUBLIC, anon, authenticated;

revoke all on function public.clear_written_attempt_response(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.submit_practice_attempt(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.get_practice_attempt_review(uuid)
from PUBLIC, anon, authenticated;

revoke all on function public.save_written_self_assessment(uuid, text)
from PUBLIC, anon, authenticated;

revoke all on function public.get_candidate_course_overview()
from PUBLIC, anon, authenticated;

revoke all on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
from PUBLIC, anon, authenticated;

revoke all on function public.get_candidate_course_offering_detail(uuid)
from PUBLIC, anon, authenticated;

grant execute on function public.get_practice_attempt_state(uuid)
to authenticated;

grant execute on function public.start_practice_attempt(uuid)
to authenticated;

grant execute on function public.save_objective_attempt_response(uuid, uuid)
to authenticated;

grant execute on function public.clear_objective_attempt_response(uuid)
to authenticated;

grant execute on function public.save_written_attempt_response(uuid, text, boolean)
to authenticated;

grant execute on function public.clear_written_attempt_response(uuid)
to authenticated;

grant execute on function public.submit_practice_attempt(uuid)
to authenticated;

grant execute on function public.get_practice_attempt_review(uuid)
to authenticated;

grant execute on function public.save_written_self_assessment(uuid, text)
to authenticated;

grant execute on function public.get_candidate_course_overview()
to authenticated;

grant execute on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
to authenticated;

grant execute on function public.get_candidate_course_offering_detail(uuid)
to authenticated;

commit;
