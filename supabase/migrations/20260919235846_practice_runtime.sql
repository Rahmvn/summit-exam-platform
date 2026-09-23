begin;

create unique index practice_attempts_one_in_progress_per_user_set_idx
  on public.practice_attempts (user_id, practice_set_id)
  where status = 'in_progress';

alter table public.written_attempt_responses
  add constraint written_attempt_responses_length_check check (
    response_text is null
    or pg_catalog.char_length(response_text) <= 10000
  );

alter table public.objective_attempt_results
  add constraint objective_attempt_results_percentage_consistent_check check (
    score_percentage = pg_catalog.round(
      (correct_count::numeric * 100.0) / total_questions::numeric,
      2
    )
  );

create function public.get_practice_attempt_state(p_attempt_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt public.practice_attempts%rowtype;
  v_questions jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select practice_attempts.*
  into v_attempt
  from public.practice_attempts
  where practice_attempts.id = p_attempt_id
    and practice_attempts.user_id = v_user_id;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  if v_attempt.status = 'in_progress' then
    if v_attempt.exam_mode_snapshot = 'cbt' then
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'attempt_question_id', attempt_questions.id,
            'position', attempt_questions.position,
            'question_text', attempt_questions.question_text_snapshot,
            'options', (
              select coalesce(
                jsonb_agg(
                  jsonb_build_object(
                    'attempt_option_id', attempt_objective_options.id,
                    'position', attempt_objective_options.position,
                    'option_text', attempt_objective_options.option_text_snapshot
                  ) order by attempt_objective_options.position
                ),
                '[]'::jsonb
              )
              from public.attempt_objective_options
              where attempt_objective_options.attempt_question_id = attempt_questions.id
            ),
            'selected_attempt_option_id', objective_attempt_responses.selected_attempt_option_id
          ) order by attempt_questions.position
        ),
        '[]'::jsonb
      )
      into v_questions
      from public.attempt_questions
      left join public.objective_attempt_responses
        on objective_attempt_responses.attempt_question_id = attempt_questions.id
      where attempt_questions.attempt_id = v_attempt.id;
    else
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'attempt_question_id', attempt_questions.id,
            'position', attempt_questions.position,
            'question_text', attempt_questions.question_text_snapshot,
            'response_text', written_attempt_responses.response_text,
            'is_skipped', written_attempt_responses.is_skipped
          ) order by attempt_questions.position
        ),
        '[]'::jsonb
      )
      into v_questions
      from public.attempt_questions
      left join public.written_attempt_responses
        on written_attempt_responses.attempt_question_id = attempt_questions.id
      where attempt_questions.attempt_id = v_attempt.id;
    end if;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'course_offering_id', v_attempt.course_offering_id,
    'practice_set_id', v_attempt.practice_set_id,
    'practice_set_title', v_attempt.practice_set_title_snapshot,
    'exam_mode', v_attempt.exam_mode_snapshot,
    'status', v_attempt.status,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'questions', v_questions
  );
end;
$$;

create function public.start_practice_attempt(p_practice_set_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_attempt_id uuid;
  v_course_offering_id uuid;
  v_practice_set_title text;
  v_exam_mode text;
  v_practice_set_status text;
  v_practice_set_is_active boolean;
  v_course_offering_is_active boolean;
  v_question_count integer;
  v_snapshot_question_count integer;
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

  select practice_attempts.id
  into v_attempt_id
  from public.practice_attempts
  where practice_attempts.user_id = v_user_id
    and practice_attempts.practice_set_id = p_practice_set_id
    and practice_attempts.status = 'in_progress'
  for update;

  if found then
    return public.get_practice_attempt_state(v_attempt_id);
  end if;

  select
    practice_sets.course_offering_id,
    practice_sets.title,
    practice_sets.status,
    practice_sets.is_active,
    course_offerings.exam_mode,
    course_offerings.is_active
  into
    v_course_offering_id,
    v_practice_set_title,
    v_practice_set_status,
    v_practice_set_is_active,
    v_exam_mode,
    v_course_offering_is_active
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

  if not public.has_active_course_access(v_course_offering_id) then
    raise exception 'Active Course Access is required to start a new Attempt'
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

  if exists (
    select 1
    from public.practice_set_questions
    join public.questions
      on questions.id = practice_set_questions.question_id
    where practice_set_questions.practice_set_id = p_practice_set_id
      and (
        practice_set_questions.course_offering_id <> v_course_offering_id
        or questions.course_offering_id <> v_course_offering_id
        or questions.status <> 'published'
        or not questions.is_active
      )
  ) then
    raise exception 'Every Question must be active, published and belong to the Practice Set Course Offering'
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

  insert into public.practice_attempts (
    user_id,
    course_offering_id,
    practice_set_id,
    exam_mode_snapshot,
    practice_set_title_snapshot
  )
  values (
    v_user_id,
    v_course_offering_id,
    p_practice_set_id,
    v_exam_mode,
    v_practice_set_title
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

  if v_attempt.status <> 'in_progress' then
    raise exception 'Submitted Attempts cannot be changed'
      using errcode = '55000';
  end if;

  if v_attempt.exam_mode_snapshot <> 'cbt' then
    raise exception 'Objective responses are allowed only for CBT Attempts'
      using errcode = '23514';
  end if;

  if not exists (
    select 1
    from public.attempt_objective_options
    where attempt_objective_options.id = p_selected_attempt_option_id
      and attempt_objective_options.attempt_question_id = p_attempt_question_id
  ) then
    raise exception 'The selected option does not belong to this Attempt Question'
      using errcode = '23503';
  end if;

  insert into public.objective_attempt_responses (
    attempt_question_id,
    selected_attempt_option_id
  )
  values (
    p_attempt_question_id,
    p_selected_attempt_option_id
  )
  on conflict (attempt_question_id) do update
  set selected_attempt_option_id = excluded.selected_attempt_option_id,
      answered_at = pg_catalog.now();

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'selected_attempt_option_id', p_selected_attempt_option_id,
    'state', 'answered'
  );
end;
$$;

create function public.clear_objective_attempt_response(p_attempt_question_id uuid)
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

  if v_attempt.status <> 'in_progress' then
    raise exception 'Submitted Attempts cannot be changed'
      using errcode = '55000';
  end if;

  if v_attempt.exam_mode_snapshot <> 'cbt' then
    raise exception 'Objective responses are allowed only for CBT Attempts'
      using errcode = '23514';
  end if;

  delete from public.objective_attempt_responses
  where objective_attempt_responses.attempt_question_id = p_attempt_question_id;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'selected_attempt_option_id', null,
    'state', 'unanswered'
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

  if v_attempt.status <> 'in_progress' then
    raise exception 'Submitted Attempts cannot be changed'
      using errcode = '55000';
  end if;

  if v_attempt.exam_mode_snapshot <> 'written' then
    raise exception 'Written responses are allowed only for Written Attempts'
      using errcode = '23514';
  end if;

  if p_is_skipped is null then
    raise exception 'Written response state is required'
      using errcode = '22004';
  end if;

  if p_is_skipped and p_response_text is not null then
    raise exception 'A skipped Written response cannot contain answer text'
      using errcode = '23514';
  end if;

  if not p_is_skipped and (
    p_response_text is null
    or pg_catalog.btrim(p_response_text) = ''
  ) then
    raise exception 'A Written answer must contain nonblank text'
      using errcode = '23514';
  end if;

  if p_response_text is not null
     and pg_catalog.char_length(p_response_text) > 10000 then
    raise exception 'A Written answer cannot exceed 10000 characters'
      using errcode = '22001';
  end if;

  insert into public.written_attempt_responses (
    attempt_question_id,
    response_text,
    is_skipped
  )
  values (
    p_attempt_question_id,
    p_response_text,
    p_is_skipped
  )
  on conflict (attempt_question_id) do update
  set response_text = excluded.response_text,
      is_skipped = excluded.is_skipped,
      answered_at = pg_catalog.now();

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'response_text', p_response_text,
    'is_skipped', p_is_skipped,
    'state', case when p_is_skipped then 'skipped' else 'answered' end
  );
end;
$$;

create function public.clear_written_attempt_response(p_attempt_question_id uuid)
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

  if v_attempt.status <> 'in_progress' then
    raise exception 'Submitted Attempts cannot be changed'
      using errcode = '55000';
  end if;

  if v_attempt.exam_mode_snapshot <> 'written' then
    raise exception 'Written responses are allowed only for Written Attempts'
      using errcode = '23514';
  end if;

  delete from public.written_attempt_responses
  where written_attempt_responses.attempt_question_id = p_attempt_question_id;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'response_text', null,
    'is_skipped', null,
    'state', 'unanswered'
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
  v_total_questions integer;
  v_correct_count integer;
  v_score_percentage numeric(5, 2);
  v_missing_response_count integer;
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

  if v_attempt.status = 'submitted' then
    if v_attempt.exam_mode_snapshot = 'cbt' then
      select jsonb_build_object(
        'correct_count', objective_attempt_results.correct_count,
        'total_questions', objective_attempt_results.total_questions,
        'score_percentage', objective_attempt_results.score_percentage
      )
      into v_result
      from public.objective_attempt_results
      where objective_attempt_results.attempt_id = v_attempt.id;

      if v_result is null then
        raise exception 'The submitted CBT Attempt result is missing'
          using errcode = '23514';
      end if;
    else
      v_result := null;
    end if;

    return jsonb_build_object(
      'attempt_id', v_attempt.id,
      'exam_mode', v_attempt.exam_mode_snapshot,
      'status', v_attempt.status,
      'submitted_at', v_attempt.submitted_at,
      'result', v_result
    );
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
    );

    update public.practice_attempts
    set status = 'submitted',
        submitted_at = pg_catalog.now()
    where practice_attempts.id = v_attempt.id
    returning * into v_attempt;

    v_result := jsonb_build_object(
      'correct_count', v_correct_count,
      'total_questions', v_total_questions,
      'score_percentage', v_score_percentage
    );
  else
    select count(*)::integer
    into v_missing_response_count
    from public.attempt_questions
    left join public.written_attempt_responses
      on written_attempt_responses.attempt_question_id = attempt_questions.id
    where attempt_questions.attempt_id = v_attempt.id
      and written_attempt_responses.attempt_question_id is null;

    if v_missing_response_count > 0 then
      raise exception 'Every Written Question must be answered or explicitly skipped before submission'
        using errcode = '23514';
    end if;

    update public.practice_attempts
    set status = 'submitted',
        submitted_at = pg_catalog.now()
    where practice_attempts.id = v_attempt.id
    returning * into v_attempt;

    v_result := null;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'exam_mode', v_attempt.exam_mode_snapshot,
    'status', v_attempt.status,
    'submitted_at', v_attempt.submitted_at,
    'result', v_result
  );
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
  v_questions jsonb;
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
    and practice_attempts.user_id = v_user_id;

  if not found then
    raise exception 'Practice Attempt % was not found', p_attempt_id
      using errcode = 'P0002';
  end if;

  if v_attempt.status <> 'submitted' then
    raise exception 'Submit the Attempt before opening Review'
      using errcode = '55000';
  end if;

  if v_attempt.exam_mode_snapshot = 'cbt' then
    select jsonb_build_object(
      'correct_count', objective_attempt_results.correct_count,
      'total_questions', objective_attempt_results.total_questions,
      'score_percentage', objective_attempt_results.score_percentage
    )
    into v_result
    from public.objective_attempt_results
    where objective_attempt_results.attempt_id = v_attempt.id;

    if v_result is null then
      raise exception 'The submitted CBT Attempt result is missing'
        using errcode = '23514';
    end if;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'attempt_question_id', attempt_questions.id,
          'position', attempt_questions.position,
          'question_text', attempt_questions.question_text_snapshot,
          'options', (
            select coalesce(
              jsonb_agg(
                jsonb_build_object(
                  'attempt_option_id', attempt_objective_options.id,
                  'position', attempt_objective_options.position,
                  'option_text', attempt_objective_options.option_text_snapshot,
                  'is_selected', attempt_objective_options.id
                    = objective_attempt_responses.selected_attempt_option_id,
                  'is_correct_option', attempt_objective_options.id
                    = attempt_objective_answer_keys.correct_attempt_option_id
                ) order by attempt_objective_options.position
              ),
              '[]'::jsonb
            )
            from public.attempt_objective_options
            where attempt_objective_options.attempt_question_id = attempt_questions.id
          ),
          'selected_attempt_option_id', objective_attempt_responses.selected_attempt_option_id,
          'correct_attempt_option_id', attempt_objective_answer_keys.correct_attempt_option_id,
          'is_correct', coalesce(
            objective_attempt_responses.selected_attempt_option_id
              = attempt_objective_answer_keys.correct_attempt_option_id,
            false
          ),
          'explanation', attempt_review_content.explanation_snapshot,
          'reference_note', attempt_review_content.reference_note_snapshot
        ) order by attempt_questions.position
      ),
      '[]'::jsonb
    )
    into v_questions
    from public.attempt_questions
    join public.attempt_objective_answer_keys
      on attempt_objective_answer_keys.attempt_question_id = attempt_questions.id
    left join public.objective_attempt_responses
      on objective_attempt_responses.attempt_question_id = attempt_questions.id
    left join public.attempt_review_content
      on attempt_review_content.attempt_question_id = attempt_questions.id
    where attempt_questions.attempt_id = v_attempt.id;
  else
    v_result := null;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'attempt_question_id', attempt_questions.id,
          'position', attempt_questions.position,
          'question_text', attempt_questions.question_text_snapshot,
          'response_text', written_attempt_responses.response_text,
          'is_skipped', written_attempt_responses.is_skipped,
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
    join public.written_attempt_responses
      on written_attempt_responses.attempt_question_id = attempt_questions.id
    join public.attempt_written_answer_keys
      on attempt_written_answer_keys.attempt_question_id = attempt_questions.id
    left join public.attempt_review_content
      on attempt_review_content.attempt_question_id = attempt_questions.id
    left join public.written_self_assessments
      on written_self_assessments.attempt_question_id = attempt_questions.id
    where attempt_questions.attempt_id = v_attempt.id;
  end if;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'course_offering_id', v_attempt.course_offering_id,
    'practice_set_id', v_attempt.practice_set_id,
    'practice_set_title', v_attempt.practice_set_title_snapshot,
    'exam_mode', v_attempt.exam_mode_snapshot,
    'status', v_attempt.status,
    'started_at', v_attempt.started_at,
    'submitted_at', v_attempt.submitted_at,
    'result', v_result,
    'questions', v_questions
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

  if v_attempt.exam_mode_snapshot <> 'written' then
    raise exception 'Self-assessment is allowed only for Written Attempts'
      using errcode = '23514';
  end if;

  if v_attempt.status <> 'submitted' then
    raise exception 'Submit the Written Attempt before self-assessment'
      using errcode = '55000';
  end if;

  if p_assessment not in ('got_it', 'partially_got_it', 'did_not_get_it') then
    raise exception 'Invalid Written self-assessment value'
      using errcode = '22023';
  end if;

  insert into public.written_self_assessments (
    attempt_question_id,
    assessment
  )
  values (
    p_attempt_question_id,
    p_assessment
  )
  on conflict (attempt_question_id) do update
  set assessment = excluded.assessment;

  return jsonb_build_object(
    'attempt_id', v_attempt.id,
    'attempt_question_id', p_attempt_question_id,
    'assessment', p_assessment
  );
end;
$$;

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

commit;
