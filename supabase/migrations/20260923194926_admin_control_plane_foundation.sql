begin;

create function public.assert_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  if not exists (
    select 1
    from public.app_admins
    where app_admins.user_id = v_user_id
  ) then
    raise exception 'Admin access is required'
      using errcode = '42501';
  end if;

  return v_user_id;
end;
$$;

comment on function public.assert_admin() is
  'Internal trusted assertion for SECURITY DEFINER Admin operations. Returns the authenticated Admin user ID and does not depend on a Candidate profile.';

revoke all on function public.assert_admin()
from PUBLIC, anon, authenticated;

create table public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null,
  action text not null check (pg_catalog.btrim(action) <> ''),
  target_entity_type text not null check (pg_catalog.btrim(target_entity_type) <> ''),
  target_entity_id uuid,
  reason text check (reason is null or pg_catalog.btrim(reason) <> ''),
  metadata jsonb not null default '{}'::jsonb check (
    pg_catalog.jsonb_typeof(metadata) = 'object'
  ),
  created_at timestamptz not null default pg_catalog.now()
);

comment on table public.admin_audit_events is
  'Append-only audit history for consequential Admin operations. actor_user_id is server-derived and intentionally retained even if the Auth identity is later removed.';

create index admin_audit_events_actor_created_at_idx
  on public.admin_audit_events (actor_user_id, created_at desc);

create index admin_audit_events_target_idx
  on public.admin_audit_events (
    target_entity_type,
    target_entity_id,
    created_at desc
  );

create function public.prevent_admin_audit_event_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Admin audit events are append-only'
    using errcode = '55000';
end;
$$;

create trigger prevent_admin_audit_event_update_or_delete
before update or delete on public.admin_audit_events
for each row
execute function public.prevent_admin_audit_event_mutation();

create trigger prevent_admin_audit_event_truncate
before truncate on public.admin_audit_events
for each statement
execute function public.prevent_admin_audit_event_mutation();

create function public.record_admin_audit_event(
  p_action text,
  p_target_entity_type text,
  p_target_entity_id uuid default null,
  p_reason text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_user_id uuid;
  v_event_id uuid;
begin
  v_actor_user_id := public.assert_admin();

  if p_action is null or pg_catalog.btrim(p_action) = '' then
    raise exception 'Audit action is required'
      using errcode = '22023';
  end if;

  if p_target_entity_type is null
     or pg_catalog.btrim(p_target_entity_type) = '' then
    raise exception 'Audit target entity type is required'
      using errcode = '22023';
  end if;

  if p_reason is not null and pg_catalog.btrim(p_reason) = '' then
    raise exception 'Audit reason must be nonblank when provided'
      using errcode = '22023';
  end if;

  if p_metadata is null
     or pg_catalog.jsonb_typeof(p_metadata) <> 'object' then
    raise exception 'Audit metadata must be a JSON object'
      using errcode = '22023';
  end if;

  insert into public.admin_audit_events (
    actor_user_id,
    action,
    target_entity_type,
    target_entity_id,
    reason,
    metadata
  )
  values (
    v_actor_user_id,
    pg_catalog.btrim(p_action),
    pg_catalog.btrim(p_target_entity_type),
    p_target_entity_id,
    case
      when p_reason is null then null
      else pg_catalog.btrim(p_reason)
    end,
    p_metadata
  )
  returning id into v_event_id;

  return v_event_id;
end;
$$;

comment on function public.record_admin_audit_event(text, text, uuid, text, jsonb) is
  'Internal recorder for future Admin mutation RPCs. The actor is always derived from auth.uid() through assert_admin().';

alter table public.admin_audit_events enable row level security;

revoke all on table public.admin_audit_events
from PUBLIC, anon, authenticated;

revoke all on function public.prevent_admin_audit_event_mutation()
from PUBLIC, anon, authenticated;

revoke all on function public.record_admin_audit_event(text, text, uuid, text, jsonb)
from PUBLIC, anon, authenticated;

create function public.evaluate_practice_set_readiness(
  p_practice_set_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_practice_set_id uuid;
  v_course_offering_id uuid;
  v_practice_set_status text;
  v_exam_mode text;
  v_expected_question_count integer;
  v_practice_duration_seconds integer;
  v_actual_question_count integer;
  v_recommendation_assignment_count integer;
  v_min_position integer;
  v_max_position integer;
  v_question_ids jsonb;
  v_blockers jsonb := '[]'::jsonb;
  v_warnings jsonb := '[]'::jsonb;
begin
  select
    practice_sets.id,
    practice_sets.course_offering_id,
    practice_sets.status,
    course_offerings.exam_mode,
    course_offerings.expected_questions_per_practice_set,
    course_offerings.practice_duration_seconds
  into
    v_practice_set_id,
    v_course_offering_id,
    v_practice_set_status,
    v_exam_mode,
    v_expected_question_count,
    v_practice_duration_seconds
  from public.practice_sets
  join public.course_offerings
    on course_offerings.id = practice_sets.course_offering_id
  where practice_sets.id = p_practice_set_id;

  if not found then
    raise exception 'Practice Set % was not found', p_practice_set_id
      using errcode = 'P0002';
  end if;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.min(practice_set_questions.position),
    pg_catalog.max(practice_set_questions.position)
  into
    v_actual_question_count,
    v_min_position,
    v_max_position
  from public.practice_set_questions
  where practice_set_questions.practice_set_id = p_practice_set_id;

  select pg_catalog.count(*)::integer
  into v_recommendation_assignment_count
  from public.course_offering_departments
  join public.departments
    on departments.id = course_offering_departments.department_id
  join public.colleges
    on colleges.id = departments.college_id
  join public.levels
    on levels.id = course_offering_departments.level_id
  where course_offering_departments.course_offering_id
      = v_course_offering_id
    and course_offering_departments.is_active
    and departments.is_active
    and colleges.is_active
    and levels.is_active;

  if v_expected_question_count is null
     or v_practice_duration_seconds is null then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'OFFERING_CONFIGURATION_MISSING',
      'message', 'Configure the Offering expected Question count and practice duration before Review or publication.'
    ));
  end if;

  if v_expected_question_count is not null
     and v_actual_question_count <> v_expected_question_count then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'QUESTION_COUNT_MISMATCH',
      'message', pg_catalog.format(
        'This Practice Set contains %s Questions; the Offering requires exactly %s.',
        v_actual_question_count,
        v_expected_question_count
      )
    ));
  end if;

  if v_actual_question_count > 0
     and (v_min_position <> 1 or v_max_position <> v_actual_question_count) then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'QUESTION_POSITIONS_NOT_CONTIGUOUS',
      'message', 'Practice Set Question positions must be contiguous starting at 1.'
    ));
  end if;

  select coalesce(pg_catalog.jsonb_agg(practice_set_questions.question_id order by practice_set_questions.position), '[]'::jsonb)
  into v_question_ids
  from public.practice_set_questions
  where practice_set_questions.practice_set_id = p_practice_set_id
    and practice_set_questions.course_offering_id
      <> v_course_offering_id;

  if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'MAPPING_OFFERING_MISMATCH',
      'message', 'Every Practice Set Question mapping must belong to the Practice Set Course Offering.',
      'question_ids', v_question_ids
    ));
  end if;

  select coalesce(pg_catalog.jsonb_agg(questions.id order by practice_set_questions.position), '[]'::jsonb)
  into v_question_ids
  from public.practice_set_questions
  join public.questions
    on questions.id = practice_set_questions.question_id
  where practice_set_questions.practice_set_id = p_practice_set_id
    and questions.course_offering_id <> v_course_offering_id;

  if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'QUESTION_OFFERING_MISMATCH',
      'message', 'Every mapped Question must belong to the Practice Set Course Offering.',
      'question_ids', v_question_ids
    ));
  end if;

  select coalesce(pg_catalog.jsonb_agg(questions.id order by practice_set_questions.position), '[]'::jsonb)
  into v_question_ids
  from public.practice_set_questions
  join public.questions
    on questions.id = practice_set_questions.question_id
  where practice_set_questions.practice_set_id = p_practice_set_id
    and not questions.is_active;

  if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
    v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'INACTIVE_QUESTION',
      'message', 'Every mapped Question must be active.',
      'question_ids', v_question_ids
    ));
  end if;

  if v_exam_mode = 'cbt' then
    select coalesce(pg_catalog.jsonb_agg(invalid_questions.question_id order by invalid_questions.position), '[]'::jsonb)
    into v_question_ids
    from (
      select
        practice_set_questions.question_id,
        practice_set_questions.position
      from public.practice_set_questions
      where practice_set_questions.practice_set_id = p_practice_set_id
        and (
          select pg_catalog.count(*)
          from public.objective_question_options
          where objective_question_options.question_id
            = practice_set_questions.question_id
        ) < 2
    ) as invalid_questions;

    if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'CBT_INSUFFICIENT_OPTIONS',
        'message', 'Every CBT Question must have at least two ordered options.',
        'question_ids', v_question_ids
      ));
    end if;

    select coalesce(pg_catalog.jsonb_agg(practice_set_questions.question_id order by practice_set_questions.position), '[]'::jsonb)
    into v_question_ids
    from public.practice_set_questions
    left join public.objective_answer_keys
      on objective_answer_keys.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
      and objective_answer_keys.question_id is null;

    if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'CBT_ANSWER_KEY_MISSING',
        'message', 'Every CBT Question must have an answer key.',
        'question_ids', v_question_ids
      ));
    end if;

    select coalesce(pg_catalog.jsonb_agg(practice_set_questions.question_id order by practice_set_questions.position), '[]'::jsonb)
    into v_question_ids
    from public.practice_set_questions
    join public.objective_answer_keys
      on objective_answer_keys.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
      and not exists (
        select 1
        from public.objective_question_options
        where objective_question_options.id
            = objective_answer_keys.correct_option_id
          and objective_question_options.question_id
            = practice_set_questions.question_id
      );

    if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'CBT_ANSWER_KEY_INVALID',
        'message', 'Every CBT answer key must reference an option belonging to the same Question.',
        'question_ids', v_question_ids
      ));
    end if;
  else
    select coalesce(pg_catalog.jsonb_agg(practice_set_questions.question_id order by practice_set_questions.position), '[]'::jsonb)
    into v_question_ids
    from public.practice_set_questions
    left join public.written_answer_keys
      on written_answer_keys.question_id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
      and (
        written_answer_keys.question_id is null
        or pg_catalog.btrim(written_answer_keys.model_answer) = ''
      );

    if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'WRITTEN_MODEL_ANSWER_MISSING_OR_BLANK',
        'message', 'Every Written Question must have a nonblank model answer.',
        'question_ids', v_question_ids
      ));
    end if;

    select coalesce(pg_catalog.jsonb_agg(practice_set_questions.question_id order by practice_set_questions.position), '[]'::jsonb)
    into v_question_ids
    from public.practice_set_questions
    where practice_set_questions.practice_set_id = p_practice_set_id
      and not exists (
        select 1
        from public.written_key_points
        where written_key_points.question_id
          = practice_set_questions.question_id
      );

    if pg_catalog.jsonb_array_length(v_question_ids) > 0 then
      v_blockers := v_blockers || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
        'code', 'WRITTEN_KEY_POINTS_MISSING',
        'message', 'Every Written Question must have at least one key point.',
        'question_ids', v_question_ids
      ));
    end if;
  end if;

  if v_recommendation_assignment_count = 0 then
    v_warnings := v_warnings || pg_catalog.jsonb_build_array(pg_catalog.jsonb_build_object(
      'code', 'NO_COURSE_ASSIGNMENTS',
      'message', 'This Offering has no active Department + Level assignment eligible for profile-based recommendations.'
    ));
  end if;

  return pg_catalog.jsonb_build_object(
    'practice_set_id', v_practice_set_id,
    'course_offering_id', v_course_offering_id,
    'exam_mode', v_exam_mode,
    'practice_set_status', v_practice_set_status,
    'is_ready', pg_catalog.jsonb_array_length(v_blockers) = 0,
    'blockers', v_blockers,
    'warnings', v_warnings,
    'summary', pg_catalog.jsonb_build_object(
      'expected_question_count', v_expected_question_count,
      'actual_question_count', v_actual_question_count,
      'practice_duration_seconds', v_practice_duration_seconds,
      'recommendation_assignment_count', v_recommendation_assignment_count
    )
  );
end;
$$;

comment on function public.evaluate_practice_set_readiness(uuid) is
  'Internal read-only structural readiness evaluator shared by Admin display and future lifecycle transitions.';

revoke all on function public.evaluate_practice_set_readiness(uuid)
from PUBLIC, anon, authenticated;

create function public.admin_get_practice_set_readiness(
  p_practice_set_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform public.assert_admin();

  return public.evaluate_practice_set_readiness(p_practice_set_id);
end;
$$;

comment on function public.admin_get_practice_set_readiness(uuid) is
  'Admin-only read RPC for the shared Practice Set structural readiness result.';

revoke all on function public.admin_get_practice_set_readiness(uuid)
from PUBLIC, anon, authenticated;

grant execute on function public.admin_get_practice_set_readiness(uuid)
to authenticated;

commit;
