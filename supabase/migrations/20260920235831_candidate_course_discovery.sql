begin;

create function public.get_candidate_course_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_department_id uuid;
  v_level_id uuid;
  v_current_semester_id uuid;
  v_your_courses jsonb := '[]'::jsonb;
  v_relevant_courses jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select
    profiles.department_id,
    profiles.level_id,
    profiles.current_semester_id
  into
    v_department_id,
    v_level_id,
    v_current_semester_id
  from public.profiles
  where profiles.user_id = v_user_id;

  with active_access as (
    select
      course_access_grants.course_offering_id,
      max(course_access_grants.expires_at) as access_expires_at
    from public.course_access_grants
    where course_access_grants.user_id = v_user_id
      and course_access_grants.revoked_at is null
      and course_access_grants.starts_at <= pg_catalog.now()
      and course_access_grants.expires_at > pg_catalog.now()
    group by course_access_grants.course_offering_id
  ), course_rows as (
    select
      courses.code as course_code,
      courses.title as course_title,
      academic_sessions.start_year,
      semesters.semester_number,
      jsonb_build_object(
        'course_offering_id', course_offerings.id,
        'course_id', courses.id,
        'course_code', courses.code,
        'course_title', courses.title,
        'exam_mode', course_offerings.exam_mode,
        'semester_id', semesters.id,
        'semester_number', semesters.semester_number,
        'semester_name', semesters.name,
        'academic_session_id', academic_sessions.id,
        'academic_session_label', academic_sessions.label,
        'is_active', course_offerings.is_active,
        'has_active_access', true,
        'access_expires_at', active_access.access_expires_at
      ) as payload
    from active_access
    join public.course_offerings
      on course_offerings.id = active_access.course_offering_id
    join public.courses
      on courses.id = course_offerings.course_id
    join public.semesters
      on semesters.id = course_offerings.semester_id
    join public.academic_sessions
      on academic_sessions.id = semesters.academic_session_id
  )
  select coalesce(
    jsonb_agg(
      course_rows.payload
      order by
        course_rows.start_year desc,
        course_rows.semester_number,
        course_rows.course_code,
        course_rows.course_title
    ),
    '[]'::jsonb
  )
  into v_your_courses
  from course_rows;

  if v_department_id is not null
     and v_level_id is not null
     and v_current_semester_id is not null then
    with course_rows as (
      select
        courses.code as course_code,
        courses.title as course_title,
        jsonb_build_object(
          'course_offering_id', course_offerings.id,
          'course_id', courses.id,
          'course_code', courses.code,
          'course_title', courses.title,
          'exam_mode', course_offerings.exam_mode,
          'semester_id', semesters.id,
          'semester_number', semesters.semester_number,
          'semester_name', semesters.name,
          'academic_session_id', academic_sessions.id,
          'academic_session_label', academic_sessions.label,
          'is_active', course_offerings.is_active,
          'has_active_access', false,
          'access_expires_at', null,
          'audience', jsonb_build_object(
            'department_id', departments.id,
            'department_code', departments.code,
            'department_name', departments.name,
            'level_id', levels.id,
            'level_code', levels.code,
            'level_label', levels.label
          )
        ) as payload
      from public.course_offering_departments
      join public.course_offerings
        on course_offerings.id = course_offering_departments.course_offering_id
      join public.courses
        on courses.id = course_offerings.course_id
      join public.semesters
        on semesters.id = course_offerings.semester_id
      join public.academic_sessions
        on academic_sessions.id = semesters.academic_session_id
      join public.departments
        on departments.id = course_offering_departments.department_id
      join public.colleges
        on colleges.id = departments.college_id
      join public.levels
        on levels.id = course_offering_departments.level_id
      where course_offering_departments.department_id = v_department_id
        and course_offering_departments.level_id = v_level_id
        and course_offerings.semester_id = v_current_semester_id
        and course_offering_departments.is_active
        and course_offerings.is_active
        and courses.is_active
        and semesters.is_active
        and academic_sessions.is_active
        and departments.is_active
        and colleges.is_active
        and levels.is_active
        and not exists (
          select 1
          from public.course_access_grants
          where course_access_grants.user_id = v_user_id
            and course_access_grants.course_offering_id = course_offerings.id
            and course_access_grants.revoked_at is null
            and course_access_grants.starts_at <= pg_catalog.now()
            and course_access_grants.expires_at > pg_catalog.now()
        )
    )
    select coalesce(
      jsonb_agg(
        course_rows.payload
        order by course_rows.course_code, course_rows.course_title
      ),
      '[]'::jsonb
    )
    into v_relevant_courses
    from course_rows;
  end if;

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
  v_user_id uuid := (select auth.uid());
  v_search text := nullif(pg_catalog.btrim(p_search), '');
  v_course_offerings jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  with active_access as (
    select
      course_access_grants.course_offering_id,
      max(course_access_grants.expires_at) as access_expires_at
    from public.course_access_grants
    where course_access_grants.user_id = v_user_id
      and course_access_grants.revoked_at is null
      and course_access_grants.starts_at <= pg_catalog.now()
      and course_access_grants.expires_at > pg_catalog.now()
    group by course_access_grants.course_offering_id
  ), course_rows as (
    select
      courses.code as course_code,
      courses.title as course_title,
      academic_sessions.start_year,
      semesters.semester_number,
      jsonb_build_object(
        'course_offering_id', course_offerings.id,
        'course_id', courses.id,
        'course_code', courses.code,
        'course_title', courses.title,
        'exam_mode', course_offerings.exam_mode,
        'semester_id', semesters.id,
        'semester_number', semesters.semester_number,
        'semester_name', semesters.name,
        'academic_session_id', academic_sessions.id,
        'academic_session_label', academic_sessions.label,
        'is_active', course_offerings.is_active,
        'has_active_access', active_access.course_offering_id is not null,
        'access_expires_at', active_access.access_expires_at,
        'audiences', (
          select coalesce(
            jsonb_agg(
              jsonb_build_object(
                'college_id', colleges.id,
                'college_code', colleges.code,
                'college_name', colleges.name,
                'department_id', departments.id,
                'department_code', departments.code,
                'department_name', departments.name,
                'level_id', levels.id,
                'level_code', levels.code,
                'level_label', levels.label
              ) order by
                colleges.name,
                departments.name,
                levels.sort_order
            ),
            '[]'::jsonb
          )
          from public.course_offering_departments as audience_mappings
          join public.departments
            on departments.id = audience_mappings.department_id
          join public.colleges
            on colleges.id = departments.college_id
          join public.levels
            on levels.id = audience_mappings.level_id
          where audience_mappings.course_offering_id = course_offerings.id
            and audience_mappings.is_active
            and departments.is_active
            and colleges.is_active
            and levels.is_active
        )
      ) as payload
    from public.course_offerings
    join public.courses
      on courses.id = course_offerings.course_id
    join public.semesters
      on semesters.id = course_offerings.semester_id
    join public.academic_sessions
      on academic_sessions.id = semesters.academic_session_id
    left join active_access
      on active_access.course_offering_id = course_offerings.id
    where course_offerings.is_active
      and courses.is_active
      and semesters.is_active
      and academic_sessions.is_active
      and (p_semester_id is null or course_offerings.semester_id = p_semester_id)
      and (
        v_search is null
        or courses.code ilike '%' || v_search || '%'
        or courses.title ilike '%' || v_search || '%'
      )
      and exists (
        select 1
        from public.course_offering_departments as filter_mappings
        join public.departments
          on departments.id = filter_mappings.department_id
        join public.colleges
          on colleges.id = departments.college_id
        join public.levels
          on levels.id = filter_mappings.level_id
        where filter_mappings.course_offering_id = course_offerings.id
          and filter_mappings.is_active
          and departments.is_active
          and colleges.is_active
          and levels.is_active
          and (p_college_id is null or colleges.id = p_college_id)
          and (p_department_id is null or departments.id = p_department_id)
          and (p_level_id is null or levels.id = p_level_id)
      )
  )
  select coalesce(
    jsonb_agg(
      course_rows.payload
      order by
        course_rows.start_year desc,
        course_rows.semester_number,
        course_rows.course_code,
        course_rows.course_title
    ),
    '[]'::jsonb
  )
  into v_course_offerings
  from course_rows;

  return v_course_offerings;
end;
$$;

create function public.get_candidate_course_offering_detail(
  p_course_offering_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_access_expires_at timestamptz;
  v_detail jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication is required'
      using errcode = '28000';
  end if;

  select max(course_access_grants.expires_at)
  into v_access_expires_at
  from public.course_access_grants
  where course_access_grants.user_id = v_user_id
    and course_access_grants.course_offering_id = p_course_offering_id
    and course_access_grants.revoked_at is null
    and course_access_grants.starts_at <= pg_catalog.now()
    and course_access_grants.expires_at > pg_catalog.now();

  select jsonb_build_object(
    'course_offering_id', course_offerings.id,
    'course_id', courses.id,
    'course_code', courses.code,
    'course_title', courses.title,
    'exam_mode', course_offerings.exam_mode,
    'semester_id', semesters.id,
    'semester_number', semesters.semester_number,
    'semester_name', semesters.name,
    'academic_session_id', academic_sessions.id,
    'academic_session_label', academic_sessions.label,
    'is_active', course_offerings.is_active,
    'has_active_access', v_access_expires_at is not null,
    'access_expires_at', v_access_expires_at,
    'audiences', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'college_id', colleges.id,
            'college_code', colleges.code,
            'college_name', colleges.name,
            'department_id', departments.id,
            'department_code', departments.code,
            'department_name', departments.name,
            'level_id', levels.id,
            'level_code', levels.code,
            'level_label', levels.label
          ) order by
            colleges.name,
            departments.name,
            levels.sort_order
        ),
        '[]'::jsonb
      )
      from public.course_offering_departments
      join public.departments
        on departments.id = course_offering_departments.department_id
      join public.colleges
        on colleges.id = departments.college_id
      join public.levels
        on levels.id = course_offering_departments.level_id
      where course_offering_departments.course_offering_id = course_offerings.id
        and course_offering_departments.is_active
        and departments.is_active
        and colleges.is_active
        and levels.is_active
    ),
    'practice_sets', (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'practice_set_id', practice_sets.id,
            'title', practice_sets.title,
            'position', practice_sets.position,
            'question_count', (
              select count(*)::integer
              from public.practice_set_questions
              where practice_set_questions.practice_set_id = practice_sets.id
            ),
            'in_progress_attempt_id', (
              select practice_attempts.id
              from public.practice_attempts
              where practice_attempts.user_id = v_user_id
                and practice_attempts.practice_set_id = practice_sets.id
                and practice_attempts.status = 'in_progress'
              limit 1
            )
          ) order by practice_sets.position
        ),
        '[]'::jsonb
      )
      from public.practice_sets
      where practice_sets.course_offering_id = course_offerings.id
        and practice_sets.status = 'published'
        and practice_sets.is_active
    )
  )
  into v_detail
  from public.course_offerings
  join public.courses
    on courses.id = course_offerings.course_id
  join public.semesters
    on semesters.id = course_offerings.semester_id
  join public.academic_sessions
    on academic_sessions.id = semesters.academic_session_id
  where course_offerings.id = p_course_offering_id;

  if v_detail is null then
    raise exception 'Course Offering % was not found', p_course_offering_id
      using errcode = 'P0002';
  end if;

  return v_detail;
end;
$$;

revoke all on function public.get_candidate_course_overview()
from PUBLIC, anon, authenticated;

revoke all on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
from PUBLIC, anon, authenticated;

revoke all on function public.get_candidate_course_offering_detail(uuid)
from PUBLIC, anon, authenticated;

grant execute on function public.get_candidate_course_overview()
to authenticated;

grant execute on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
to authenticated;

grant execute on function public.get_candidate_course_offering_detail(uuid)
to authenticated;

commit;
