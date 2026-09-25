begin;

create function public.evaluate_practice_set_readiness_with_configuration(
  p_practice_set_id uuid,
  p_expected_questions_per_practice_set integer,
  p_practice_duration_seconds integer
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
  v_expected_question_count integer := p_expected_questions_per_practice_set;
  v_practice_duration_seconds integer := p_practice_duration_seconds;
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
    course_offerings.exam_mode
  into
    v_practice_set_id,
    v_course_offering_id,
    v_practice_set_status,
    v_exam_mode
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

create or replace function public.evaluate_practice_set_readiness(
  p_practice_set_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_expected_question_count integer;
  v_practice_duration_seconds integer;
begin
  select
    course_offerings.expected_questions_per_practice_set,
    course_offerings.practice_duration_seconds
  into v_expected_question_count, v_practice_duration_seconds
  from public.practice_sets
  join public.course_offerings
    on course_offerings.id = practice_sets.course_offering_id
  where practice_sets.id = p_practice_set_id;

  if not found then
    raise exception 'Practice Set % was not found', p_practice_set_id
      using errcode = 'P0002';
  end if;

  return public.evaluate_practice_set_readiness_with_configuration(
    p_practice_set_id,
    v_expected_question_count,
    v_practice_duration_seconds
  );
end;
$$;

revoke all on function public.evaluate_practice_set_readiness_with_configuration(uuid, integer, integer)
from PUBLIC, anon, authenticated;

create function public.admin_update_course_offering_practice_configuration(
  p_course_offering_id uuid,
  p_expected_question_count integer,
  p_expected_duration_seconds integer,
  p_new_question_count integer,
  p_new_duration_seconds integer,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_count integer;
  v_old_duration integer;
  v_updated_id uuid;
  v_count_changed boolean;
  v_reason text;
  v_readiness jsonb;
  v_protected jsonb := '[]'::jsonb;
  v_failing jsonb := '[]'::jsonb;
  v_changed_fields jsonb := '[]'::jsonb;
  v_set record;
  v_audit_id uuid;
begin
  perform public.assert_admin();
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'Phase 3 Offering control requires READ COMMITTED transaction isolation'
      using errcode = '0A000';
  end if;
  if p_course_offering_id is null or p_new_question_count is null
     or p_new_duration_seconds is null or p_new_question_count <= 0
     or p_new_duration_seconds <= 0 then
    raise exception 'An Offering ID and positive Question count and duration are required'
      using errcode = '22023';
  end if;
  v_reason := case when p_reason is null then null
    else nullif(pg_catalog.btrim(p_reason, E' \t\n\r\f\v'), '') end;

  select expected_questions_per_practice_set, practice_duration_seconds
  into v_old_count, v_old_duration
  from public.course_offerings
  where id = p_course_offering_id
  for update;
  if not found then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;
  if (v_old_count is null) <> (v_old_duration is null) then
    raise exception 'Course Offering % has inconsistent practice configuration', p_course_offering_id
      using errcode = '23514';
  end if;
  if v_old_count is distinct from p_expected_question_count
     or v_old_duration is distinct from p_expected_duration_seconds then
    raise exception 'Course Offering practice configuration changed'
      using errcode = '40001';
  end if;
  if v_old_count is not distinct from p_new_question_count
     and v_old_duration is not distinct from p_new_duration_seconds then
    raise exception 'Practice configuration is unchanged'
      using errcode = '22023';
  end if;
  if v_old_count is not null and v_reason is null then
    raise exception 'A nonblank reason is required to change configured practice settings'
      using errcode = '22023';
  end if;

  v_count_changed := v_old_count is distinct from p_new_question_count;
  if v_count_changed then
    v_changed_fields := v_changed_fields || '"expected_questions_per_practice_set"'::jsonb;
  end if;
  if v_old_duration is distinct from p_new_duration_seconds then
    v_changed_fields := v_changed_fields || '"practice_duration_seconds"'::jsonb;
  end if;

  if v_count_changed then
    begin
      for v_set in
        select id from public.practice_sets
        where course_offering_id = p_course_offering_id
        order by id
        for update nowait
      loop
        null;
      end loop;
    exception when lock_not_available then
      raise exception 'A Practice Set is being changed; retry the Offering configuration update'
        using errcode = '40001';
    end;

    -- A separate statement gets a fresh READ COMMITTED snapshot after all locks.
    for v_set in
      select id, status from public.practice_sets
      where course_offering_id = p_course_offering_id
        and status in ('review', 'published')
      order by id
    loop
      v_readiness := public.evaluate_practice_set_readiness_with_configuration(
        v_set.id, p_new_question_count, p_new_duration_seconds
      );
      v_protected := v_protected || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'practice_set_id', v_set.id,
          'status', v_set.status,
          'is_ready', v_readiness -> 'is_ready',
          'blockers', v_readiness -> 'blockers',
          'warnings', v_readiness -> 'warnings'
        )
      );
      if not coalesce((v_readiness ->> 'is_ready')::boolean, false) then
        v_failing := v_failing || pg_catalog.jsonb_build_array(v_set.id);
      end if;
    end loop;
    if pg_catalog.jsonb_array_length(v_failing) > 0 then
      raise exception 'Proposed Question count leaves protected Practice Sets unready'
        using errcode = '23514',
          detail = pg_catalog.jsonb_build_object(
            'failing_practice_set_ids', v_failing,
            'protected_sets', v_protected
          )::text;
    end if;
  end if;

  update public.course_offerings
  set expected_questions_per_practice_set = p_new_question_count,
      practice_duration_seconds = p_new_duration_seconds
  where id = p_course_offering_id
    and expected_questions_per_practice_set is not distinct from p_expected_question_count
    and practice_duration_seconds is not distinct from p_expected_duration_seconds
  returning id into v_updated_id;
  if v_updated_id is null then
    raise exception 'Course Offering configuration update did not update exactly one row'
      using errcode = '40001';
  end if;

  v_audit_id := public.record_admin_audit_event(
    p_action => 'course_offering.configuration_updated',
    p_target_entity_type => 'course_offering',
    p_target_entity_id => p_course_offering_id,
    p_reason => v_reason,
    p_metadata => pg_catalog.jsonb_build_object(
      'previous_question_count', v_old_count,
      'previous_duration_seconds', v_old_duration,
      'new_question_count', p_new_question_count,
      'new_duration_seconds', p_new_duration_seconds,
      'changed_fields', v_changed_fields,
      'protected_set_check', pg_catalog.jsonb_build_object(
        'performed', v_count_changed,
        'checked_count', pg_catalog.jsonb_array_length(v_protected),
        'failing_count', 0
      )
    )
  );
  return pg_catalog.jsonb_build_object(
    'course_offering_id', p_course_offering_id,
    'previous', pg_catalog.jsonb_build_object('question_count', v_old_count, 'duration_seconds', v_old_duration),
    'current', pg_catalog.jsonb_build_object('question_count', p_new_question_count, 'duration_seconds', p_new_duration_seconds),
    'impact', pg_catalog.jsonb_build_object('changed_fields', v_changed_fields, 'protected_sets', v_protected),
    'audit_event_id', v_audit_id
  );
end;
$$;

create function public.admin_change_course_offering_exam_mode(
  p_course_offering_id uuid,
  p_expected_exam_mode text,
  p_new_exam_mode text,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_mode text;
  v_updated_id uuid;
  v_reason text;
  v_question_count integer;
  v_attempt_count integer;
  v_review_count integer;
  v_published_count integer;
  v_archived_count integer;
  v_summary jsonb;
  v_set record;
  v_audit_id uuid;
begin
  perform public.assert_admin();
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'Phase 3 Offering control requires READ COMMITTED transaction isolation'
      using errcode = '0A000';
  end if;
  if p_course_offering_id is null
     or p_expected_exam_mode is null or p_expected_exam_mode not in ('cbt', 'written')
     or p_new_exam_mode is null or p_new_exam_mode not in ('cbt', 'written') then
    raise exception 'An Offering ID and valid expected/new exam modes are required'
      using errcode = '22023';
  end if;
  v_reason := case when p_reason is null then null
    else nullif(pg_catalog.btrim(p_reason, E' \t\n\r\f\v'), '') end;
  if v_reason is null then
    raise exception 'A nonblank reason is required for an exam-mode change'
      using errcode = '22023';
  end if;

  select exam_mode into v_old_mode
  from public.course_offerings
  where id = p_course_offering_id
  for update;
  if not found then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;
  if v_old_mode is distinct from p_expected_exam_mode then
    raise exception 'Course Offering exam mode changed'
      using errcode = '40001';
  end if;
  if v_old_mode = p_new_exam_mode then
    raise exception 'Course Offering exam mode is unchanged'
      using errcode = '22023';
  end if;

  begin
    for v_set in
      select id from public.practice_sets
      where course_offering_id = p_course_offering_id
      order by id
      for update nowait
    loop
      null;
    end loop;
  exception when lock_not_available then
    raise exception 'A Practice Set is being changed; retry the Offering exam-mode change'
      using errcode = '40001';
  end;

  -- These counts use a fresh statement snapshot after the child locks.
  select
    (select count(*)::integer from public.questions where course_offering_id = p_course_offering_id),
    (select count(*)::integer from public.practice_attempts where course_offering_id = p_course_offering_id),
    (select count(*)::integer from public.practice_sets where course_offering_id = p_course_offering_id and status = 'review'),
    (select count(*)::integer from public.practice_sets where course_offering_id = p_course_offering_id and status = 'published'),
    (select count(*)::integer from public.practice_sets where course_offering_id = p_course_offering_id and status = 'archived')
  into v_question_count, v_attempt_count, v_review_count, v_published_count, v_archived_count;
  v_summary := pg_catalog.jsonb_build_object(
    'question_count', v_question_count,
    'attempt_count', v_attempt_count,
    'review_set_count', v_review_count,
    'published_set_count', v_published_count,
    'archived_set_count', v_archived_count
  );
  if v_question_count > 0 or v_attempt_count > 0 or v_review_count > 0
     or v_published_count > 0 or v_archived_count > 0 then
    raise exception 'Course Offering exam-mode change is blocked by existing content or history'
      using errcode = '23514', detail = v_summary::text;
  end if;

  update public.course_offerings
  set exam_mode = p_new_exam_mode
  where id = p_course_offering_id and exam_mode = p_expected_exam_mode
  returning id into v_updated_id;
  if v_updated_id is null then
    raise exception 'Course Offering exam-mode update did not update exactly one row'
      using errcode = '40001';
  end if;
  v_audit_id := public.record_admin_audit_event(
    p_action => 'course_offering.exam_mode_changed',
    p_target_entity_type => 'course_offering',
    p_target_entity_id => p_course_offering_id,
    p_reason => v_reason,
    p_metadata => pg_catalog.jsonb_build_object(
      'previous_mode', v_old_mode,
      'new_mode', p_new_exam_mode,
      'eligibility', v_summary
    )
  );
  return pg_catalog.jsonb_build_object(
    'course_offering_id', p_course_offering_id,
    'previous_mode', v_old_mode,
    'current_mode', p_new_exam_mode,
    'impact', v_summary,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function public.admin_set_course_offering_activity(
  p_course_offering_id uuid,
  p_expected_is_active boolean,
  p_new_is_active boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_is_active boolean;
  v_updated_id uuid;
  v_reason text;
  v_impact jsonb;
  v_audit_id uuid;
begin
  perform public.assert_admin();
  if pg_catalog.current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'Phase 3 Offering control requires READ COMMITTED transaction isolation'
      using errcode = '0A000';
  end if;
  if p_course_offering_id is null or p_expected_is_active is null
     or p_new_is_active is null then
    raise exception 'Offering ID and expected/new activity states are required'
      using errcode = '22023';
  end if;
  v_reason := case when p_reason is null then null
    else nullif(pg_catalog.btrim(p_reason, E' \t\n\r\f\v'), '') end;
  if not p_new_is_active and v_reason is null then
    raise exception 'A nonblank reason is required to deactivate an Offering'
      using errcode = '22023';
  end if;

  select is_active into v_old_is_active
  from public.course_offerings
  where id = p_course_offering_id
  for update;
  if not found then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;
  if v_old_is_active is distinct from p_expected_is_active then
    raise exception 'Course Offering activity changed'
      using errcode = '40001';
  end if;
  if v_old_is_active = p_new_is_active then
    raise exception 'Course Offering activity is unchanged'
      using errcode = '22023';
  end if;

  select pg_catalog.jsonb_build_object(
    'published_set_count',
      (select count(*)::integer from public.practice_sets
       where course_offering_id = p_course_offering_id and status = 'published'),
    'effective_grant_count',
      (select count(*)::integer from public.course_access_grants
       where course_offering_id = p_course_offering_id
         and revoked_at is null and starts_at <= pg_catalog.now()
         and expires_at > pg_catalog.now()),
    'in_progress_attempt_count',
      (select count(*)::integer from public.practice_attempts
       where course_offering_id = p_course_offering_id and status = 'in_progress')
  ) into v_impact;

  update public.course_offerings
  set is_active = p_new_is_active
  where id = p_course_offering_id and is_active = p_expected_is_active
  returning id into v_updated_id;
  if v_updated_id is null then
    raise exception 'Course Offering activity update did not update exactly one row'
      using errcode = '40001';
  end if;
  v_audit_id := public.record_admin_audit_event(
    p_action => 'course_offering.activity_changed',
    p_target_entity_type => 'course_offering',
    p_target_entity_id => p_course_offering_id,
    p_reason => v_reason,
    p_metadata => pg_catalog.jsonb_build_object(
      'previous_is_active', v_old_is_active,
      'new_is_active', p_new_is_active,
      'advisory_impact', v_impact
    )
  );
  return pg_catalog.jsonb_build_object(
    'course_offering_id', p_course_offering_id,
    'previous_is_active', v_old_is_active,
    'current_is_active', p_new_is_active,
    'impact', v_impact,
    'audit_event_id', v_audit_id
  );
end;
$$;

create function public.admin_get_course_offering_control_context(
  p_course_offering_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_offering record;
  v_set_counts jsonb;
  v_question_count integer;
  v_attempt_count integer;
  v_impact jsonb;
  v_mode_eligible boolean;
begin
  perform public.assert_admin();
  if p_course_offering_id is null then
    raise exception 'Course Offering ID is required' using errcode = '22023';
  end if;
  select expected_questions_per_practice_set, practice_duration_seconds,
         exam_mode, is_active
  into v_offering
  from public.course_offerings
  where id = p_course_offering_id;
  if not found then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;

  select pg_catalog.jsonb_build_object(
    'draft', count(*) filter (where status = 'draft'),
    'review', count(*) filter (where status = 'review'),
    'published', count(*) filter (where status = 'published'),
    'archived', count(*) filter (where status = 'archived')
  ) into v_set_counts
  from public.practice_sets
  where course_offering_id = p_course_offering_id;

  select count(*)::integer into v_question_count
  from public.questions where course_offering_id = p_course_offering_id;
  select count(*)::integer into v_attempt_count
  from public.practice_attempts where course_offering_id = p_course_offering_id;
  v_mode_eligible := v_question_count = 0 and v_attempt_count = 0
    and (v_set_counts ->> 'review')::bigint = 0
    and (v_set_counts ->> 'published')::bigint = 0
    and (v_set_counts ->> 'archived')::bigint = 0;

  select pg_catalog.jsonb_build_object(
    'published_set_count', (v_set_counts ->> 'published')::bigint,
    'effective_grant_count',
      (select count(*)::integer from public.course_access_grants
       where course_offering_id = p_course_offering_id
         and revoked_at is null and starts_at <= pg_catalog.now()
         and expires_at > pg_catalog.now()),
    'in_progress_attempt_count',
      (select count(*)::integer from public.practice_attempts
       where course_offering_id = p_course_offering_id and status = 'in_progress')
  ) into v_impact;

  return pg_catalog.jsonb_build_object(
    'course_offering_id', p_course_offering_id,
    'configuration', pg_catalog.jsonb_build_object(
      'question_count', v_offering.expected_questions_per_practice_set,
      'duration_seconds', v_offering.practice_duration_seconds
    ),
    'exam_mode', v_offering.exam_mode,
    'is_active', v_offering.is_active,
    'practice_set_counts', v_set_counts,
    'question_count', v_question_count,
    'attempt_count', v_attempt_count,
    'mode_change', pg_catalog.jsonb_build_object(
      'eligible', v_mode_eligible,
      'blocking_counts', pg_catalog.jsonb_build_object(
        'questions', v_question_count,
        'attempts', v_attempt_count,
        'review_sets', (v_set_counts ->> 'review')::bigint,
        'published_sets', (v_set_counts ->> 'published')::bigint,
        'archived_sets', (v_set_counts ->> 'archived')::bigint
      )
    ),
    'activity_impact', v_impact
  );
end;
$$;

create function public.admin_preview_course_offering_practice_configuration(
  p_course_offering_id uuid,
  p_new_question_count integer,
  p_new_duration_seconds integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_old_count integer;
  v_old_duration integer;
  v_count_changed boolean;
  v_unchanged boolean;
  v_protected jsonb := '[]'::jsonb;
  v_failing jsonb := '[]'::jsonb;
  v_readiness jsonb;
  v_set record;
begin
  perform public.assert_admin();
  if p_course_offering_id is null or p_new_question_count is null
     or p_new_duration_seconds is null or p_new_question_count <= 0
     or p_new_duration_seconds <= 0 then
    raise exception 'An Offering ID and positive Question count and duration are required'
      using errcode = '22023';
  end if;
  select expected_questions_per_practice_set, practice_duration_seconds
  into v_old_count, v_old_duration
  from public.course_offerings
  where id = p_course_offering_id;
  if not found then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;
  if (v_old_count is null) <> (v_old_duration is null) then
    raise exception 'Course Offering % has inconsistent practice configuration', p_course_offering_id
      using errcode = '23514';
  end if;
  v_count_changed := v_old_count is distinct from p_new_question_count;
  v_unchanged := not v_count_changed
    and v_old_duration is not distinct from p_new_duration_seconds;

  if v_count_changed then
    for v_set in
      select id, status from public.practice_sets
      where course_offering_id = p_course_offering_id
        and status in ('review', 'published')
      order by id
    loop
      v_readiness := public.evaluate_practice_set_readiness_with_configuration(
        v_set.id, p_new_question_count, p_new_duration_seconds
      );
      v_protected := v_protected || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'practice_set_id', v_set.id,
          'status', v_set.status,
          'is_ready', v_readiness -> 'is_ready',
          'blockers', v_readiness -> 'blockers',
          'warnings', v_readiness -> 'warnings'
        )
      );
      if not coalesce((v_readiness ->> 'is_ready')::boolean, false) then
        v_failing := v_failing || pg_catalog.jsonb_build_array(v_set.id);
      end if;
    end loop;
  end if;

  return pg_catalog.jsonb_build_object(
    'course_offering_id', p_course_offering_id,
    'current', pg_catalog.jsonb_build_object('question_count', v_old_count, 'duration_seconds', v_old_duration),
    'proposed', pg_catalog.jsonb_build_object('question_count', p_new_question_count, 'duration_seconds', p_new_duration_seconds),
    'count_changed', v_count_changed,
    'reason_required', v_old_count is not null and not v_unchanged,
    'can_apply', not v_unchanged and pg_catalog.jsonb_array_length(v_failing) = 0,
    'protected_sets', v_protected,
    'failing_practice_set_ids', v_failing,
    'advisory', true
  );
end;
$$;

revoke all on function public.admin_update_course_offering_practice_configuration(uuid, integer, integer, integer, integer, text)
from PUBLIC, anon, authenticated;
revoke all on function public.admin_change_course_offering_exam_mode(uuid, text, text, text)
from PUBLIC, anon, authenticated;
revoke all on function public.admin_set_course_offering_activity(uuid, boolean, boolean, text)
from PUBLIC, anon, authenticated;
revoke all on function public.admin_get_course_offering_control_context(uuid)
from PUBLIC, anon, authenticated;
revoke all on function public.admin_preview_course_offering_practice_configuration(uuid, integer, integer)
from PUBLIC, anon, authenticated;

grant execute on function public.admin_update_course_offering_practice_configuration(uuid, integer, integer, integer, integer, text)
to authenticated;
grant execute on function public.admin_change_course_offering_exam_mode(uuid, text, text, text)
to authenticated;
grant execute on function public.admin_set_course_offering_activity(uuid, boolean, boolean, text)
to authenticated;
grant execute on function public.admin_get_course_offering_control_context(uuid)
to authenticated;
grant execute on function public.admin_preview_course_offering_practice_configuration(uuid, integer, integer)
to authenticated;

commit;
