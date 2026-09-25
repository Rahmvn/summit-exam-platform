\set ON_ERROR_STOP on

insert into auth.users (id)
values ('f0000000-0000-0000-0000-000000000001');

insert into public.colleges (id, name, code, is_active)
values
  ('a0000000-0000-0000-0000-000000000001', 'Active College', 'ACT', true),
  ('a0000000-0000-0000-0000-000000000002', 'Inactive College', 'INA', false);

insert into public.departments (id, college_id, name, code, is_active)
values
  ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Candidate Department', 'CAND', true),
  ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Wrong Department', 'WRNG', true),
  ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Inactive Department', 'IDEP', false),
  ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002', 'Inactive College Department', 'ICOL', true);

update public.levels set is_active = false where code = '300';

insert into public.academic_sessions (id, start_year, end_year, is_active)
values ('c0000000-0000-0000-0000-000000000001', 2098, 2099, true);

insert into public.semesters (id, academic_session_id, semester_number, is_active)
values
  ('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001', 1, true),
  ('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000001', 2, true);

insert into public.courses (id, code, title, is_active)
values
  ('e0000000-0000-0000-0000-000000000001', 'ZRO101', 'Assignment Free Algebra', true),
  ('e0000000-0000-0000-0000-000000000002', 'MAT101', 'Exact Audience Course', true),
  ('e0000000-0000-0000-0000-000000000003', 'DEP101', 'Wrong Department Course', true),
  ('e0000000-0000-0000-0000-000000000004', 'LEV101', 'Wrong Level Course', true),
  ('e0000000-0000-0000-0000-000000000005', 'SEM101', 'Wrong Semester Course', true),
  ('e0000000-0000-0000-0000-000000000006', 'MAP101', 'Inactive Mapping Course', true),
  ('e0000000-0000-0000-0000-000000000007', 'IDP101', 'Inactive Department Course', true),
  ('e0000000-0000-0000-0000-000000000008', 'ICL101', 'Inactive College Course', true),
  ('e0000000-0000-0000-0000-000000000009', 'ILV101', 'Inactive Level Course', true);

insert into public.course_offerings (id, course_id, semester_id, exam_mode, is_active)
values
  ('10000000-0000-0000-0000-000000000001', 'e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000002', 'e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000003', 'e0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000004', 'e0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000005', 'e0000000-0000-0000-0000-000000000005', 'd0000000-0000-0000-0000-000000000002', 'cbt', true),
  ('10000000-0000-0000-0000-000000000006', 'e0000000-0000-0000-0000-000000000006', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000007', 'e0000000-0000-0000-0000-000000000007', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000008', 'e0000000-0000-0000-0000-000000000008', 'd0000000-0000-0000-0000-000000000001', 'cbt', true),
  ('10000000-0000-0000-0000-000000000009', 'e0000000-0000-0000-0000-000000000009', 'd0000000-0000-0000-0000-000000000001', 'cbt', true);

insert into public.course_offering_departments (
  course_offering_id, department_id, level_id, is_active
)
values
  ('10000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000002', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', (select id from public.levels where code = '200'), true),
  ('10000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', (select id from public.levels where code = '100'), false),
  ('10000000-0000-0000-0000-000000000007', 'b0000000-0000-0000-0000-000000000003', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000004', (select id from public.levels where code = '100'), true),
  ('10000000-0000-0000-0000-000000000009', 'b0000000-0000-0000-0000-000000000001', (select id from public.levels where code = '300'), true);

insert into public.profiles (
  user_id, full_name, matric_number, department_id, level_id, current_semester_id
)
values (
  'f0000000-0000-0000-0000-000000000001',
  'Test Candidate',
  'TEST/001',
  'b0000000-0000-0000-0000-000000000001',
  (select id from public.levels where code = '100'),
  'd0000000-0000-0000-0000-000000000001'
);

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'f0000000-0000-0000-0000-000000000001',
  false
);

create table public.discovery_test_snapshot (
  overview_payload jsonb not null,
  protected_function_definitions jsonb not null,
  table_acls jsonb not null
);

insert into public.discovery_test_snapshot
select
  public.get_candidate_course_overview(),
  (
    select jsonb_object_agg(signature, pg_get_functiondef(to_regprocedure(signature)))
    from (values
      ('public.get_candidate_course_overview()'),
      ('public.get_candidate_course_offering_detail(uuid)'),
      ('public.start_practice_attempt(uuid)'),
      ('public.evaluate_practice_set_readiness(uuid)'),
      ('public.admin_transition_practice_set(uuid,text,text,text)'),
      ('public.admin_update_course_offering_practice_configuration(uuid,integer,integer,integer,integer,text)'),
      ('public.admin_change_course_offering_exam_mode(uuid,text,text,text)'),
      ('public.admin_set_course_offering_activity(uuid,boolean,boolean,text)'),
      ('public.admin_get_course_offering_control_context(uuid)'),
      ('public.admin_preview_course_offering_practice_configuration(uuid,integer,integer)')
    ) functions(signature)
  ),
  (
    select jsonb_object_agg(c.oid::regclass::text, coalesce(c.relacl::text, '<default>'))
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r', 'p')
  );
