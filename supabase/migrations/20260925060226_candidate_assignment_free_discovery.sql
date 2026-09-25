begin;

create or replace function public.browse_course_offerings(
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

  with course_rows as (
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
      and (
        (
          p_college_id is null
          and p_department_id is null
          and p_level_id is null
        )
        or exists (
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
  )
  select coalesce(
    jsonb_agg(
      public.add_effective_access_to_course_payload(course_rows.payload)
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

revoke all on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
from PUBLIC, anon, authenticated;

grant execute on function public.browse_course_offerings(uuid, uuid, uuid, uuid, text)
to authenticated;

commit;
