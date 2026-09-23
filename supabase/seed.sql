begin;

insert into public.colleges (name, code, is_active)
values (
  'College of Innovation and Computing Technology',
  'COICT',
  true
)
on conflict (code) do update
set
  name = excluded.name,
  is_active = excluded.is_active;

insert into public.departments (college_id, name, code, is_active)
select
  colleges.id,
  'Software Engineering',
  'SOFTWARE_ENGINEERING',
  true
from public.colleges
where colleges.code = 'COICT'
on conflict (college_id, code) do update
set
  name = excluded.name,
  is_active = excluded.is_active;

insert into public.academic_sessions (start_year, end_year, is_active)
values (2026, 2027, true)
on conflict (start_year, end_year) do update
set is_active = excluded.is_active;

insert into public.semesters (
  academic_session_id,
  semester_number,
  is_active
)
select
  academic_sessions.id,
  semester_numbers.semester_number,
  true
from public.academic_sessions
cross join (
  values
    (1::smallint),
    (2::smallint)
) as semester_numbers (semester_number)
where academic_sessions.start_year = 2026
  and academic_sessions.end_year = 2027
on conflict (academic_session_id, semester_number) do update
set is_active = excluded.is_active;

commit;
