\set ON_ERROR_STOP on

select pg_catalog.set_config(
  'request.jwt.claim.sub',
  'f0000000-0000-0000-0000-000000000001',
  false
);

do $$
declare
  v_all jsonb := public.browse_course_offerings(null, null, null, null, null);
  v_code_search jsonb := public.browse_course_offerings(null, null, null, null, 'ZRO101');
  v_title_search jsonb := public.browse_course_offerings(null, null, null, null, 'Free Algebra');
  v_semester jsonb := public.browse_course_offerings(null, null, null, 'd0000000-0000-0000-0000-000000000001', null);
  v_zero jsonb;
  v_grants_before jsonb;
  v_grants_after jsonb;
begin
  select item into strict v_zero
  from jsonb_array_elements(v_all) item
  where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000001';

  if v_zero -> 'audiences' <> '[]'::jsonb then
    raise exception 'GENERAL-4: assignment-free audiences must be []';
  end if;

  if (v_zero ->> 'has_effective_access')::boolean
     or v_zero ->> 'effective_access_basis' is not null
     or v_zero ->> 'access_policy_mode' <> 'grant_required' then
    raise exception 'ACCESS-15: no-grant assignment-free Offering must remain denied';
  end if;

  if jsonb_array_length(v_code_search) <> 1
     or v_code_search -> 0 ->> 'course_offering_id' <> '10000000-0000-0000-0000-000000000001' then
    raise exception 'GENERAL-2A: course-code search failed';
  end if;

  if jsonb_array_length(v_title_search) <> 1
     or v_title_search -> 0 ->> 'course_offering_id' <> '10000000-0000-0000-0000-000000000001' then
    raise exception 'GENERAL-2B: course-title search failed';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_semester) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'GENERAL-3: matching Semester filter omitted assignment-free Offering';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_all) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'GENERAL-5: assigned Offering missing';
  end if;

  if (
    select count(*) from jsonb_array_elements(v_all) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) <> 1 then
    raise exception 'GENERAL-6: multiple assignments duplicated an Offering';
  end if;

  select coalesce(jsonb_agg(to_jsonb(g) order by g.id), '[]'::jsonb)
  into v_grants_before
  from public.course_access_grants g;

  perform public.browse_course_offerings(null, null, null, null, null);
  perform public.get_candidate_course_overview();

  select coalesce(jsonb_agg(to_jsonb(g) order by g.id), '[]'::jsonb)
  into v_grants_after
  from public.course_access_grants g;

  if v_grants_before is distinct from v_grants_after or v_grants_after <> '[]'::jsonb then
    raise exception 'ACCESS-17A: discovery created or modified a grant';
  end if;

  raise notice 'GENERAL_BROWSE_AND_DENIED_ACCESS_PASSED';
end;
$$;

do $$
declare
  v_college jsonb := public.browse_course_offerings('a0000000-0000-0000-0000-000000000001', null, null, null, null);
  v_department jsonb := public.browse_course_offerings(null, 'b0000000-0000-0000-0000-000000000001', null, null, null);
  v_level jsonb := public.browse_course_offerings(null, null, (select id from public.levels where code = '100'), null, null);
  v_combined jsonb := public.browse_course_offerings(
    'a0000000-0000-0000-0000-000000000001',
    'b0000000-0000-0000-0000-000000000001',
    (select id from public.levels where code = '100'),
    'd0000000-0000-0000-0000-000000000001',
    null
  );
  v_inactive_department jsonb := public.browse_course_offerings(null, 'b0000000-0000-0000-0000-000000000003', null, null, null);
  v_inactive_college jsonb := public.browse_course_offerings('a0000000-0000-0000-0000-000000000002', null, null, null, null);
  v_inactive_level jsonb := public.browse_course_offerings(null, null, (select id from public.levels where code = '300'), null, null);
begin
  if exists (
    select 1
    from jsonb_array_elements(v_college || v_department || v_level || v_combined) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'FILTER-11: assignment-free Offering matched an explicit audience filter';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_college) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'FILTER-7: eligible College assignment did not qualify';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_department) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'FILTER-8: eligible Department assignment did not qualify';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_level) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'FILTER-9: eligible Level assignment did not qualify';
  end if;

  if not exists (
    select 1 from jsonb_array_elements(v_combined) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000002'
  ) then
    raise exception 'FILTER-10: combined eligible mapping did not qualify';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_department) item
    where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000006'
  ) then
    raise exception 'FILTER-12: inactive mapping qualified';
  end if;

  if jsonb_array_length(v_inactive_department) <> 0
     or jsonb_array_length(v_inactive_college) <> 0
     or jsonb_array_length(v_inactive_level) <> 0 then
    raise exception 'FILTER-13: inactive Department, College, or Level qualified';
  end if;

  raise notice 'EXPLICIT_ACADEMIC_FILTERS_PASSED';
end;
$$;

do $$
declare
  v_overview jsonb := public.get_candidate_course_overview();
  v_snapshot public.discovery_test_snapshot%rowtype;
begin
  select * into strict v_snapshot from public.discovery_test_snapshot;

  if v_overview is distinct from v_snapshot.overview_payload then
    raise exception 'PROFILE-14A: overview output changed after browse replacement';
  end if;

  if jsonb_array_length(v_overview -> 'relevant_courses') <> 1
     or v_overview -> 'relevant_courses' -> 0 ->> 'course_offering_id'
       <> '10000000-0000-0000-0000-000000000002' then
    raise exception 'PROFILE-14B: exact Department/Level/current Semester recommendation failed';
  end if;

  if exists (
    select 1 from jsonb_array_elements(v_overview -> 'relevant_courses') item
    where item ->> 'course_offering_id' in (
      '10000000-0000-0000-0000-000000000001',
      '10000000-0000-0000-0000-000000000003',
      '10000000-0000-0000-0000-000000000004',
      '10000000-0000-0000-0000-000000000005'
    )
  ) then
    raise exception 'PROFILE-14C: zero-assignment or wrong-audience Offering was recommended';
  end if;

  raise notice 'PROFILE_RELEVANCE_REGRESSION_PASSED';
end;
$$;

insert into public.course_access_grants (
  id, user_id, course_offering_id, starts_at, expires_at, source_type
)
values (
  '30000000-0000-0000-0000-000000000001',
  'f0000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  pg_catalog.now() - interval '1 day',
  pg_catalog.now() + interval '30 days',
  'manual'
);

do $$
declare
  v_before jsonb;
  v_after jsonb;
  v_browse jsonb;
  v_zero jsonb;
begin
  select jsonb_agg(to_jsonb(g) order by g.id) into v_before
  from public.course_access_grants g;

  v_browse := public.browse_course_offerings(null, null, null, null, null);
  select item into strict v_zero
  from jsonb_array_elements(v_browse) item
  where item ->> 'course_offering_id' = '10000000-0000-0000-0000-000000000001';

  if not (v_zero ->> 'has_effective_access')::boolean
     or v_zero ->> 'effective_access_basis' <> 'course_access_grant' then
    raise exception 'ACCESS-16: active grant did not authorize assignment-free Offering';
  end if;

  perform public.get_candidate_course_overview();
  perform public.get_candidate_course_offering_detail('10000000-0000-0000-0000-000000000001');

  select jsonb_agg(to_jsonb(g) order by g.id) into v_after
  from public.course_access_grants g;

  if v_before is distinct from v_after then
    raise exception 'ACCESS-17B: discovery modified the active grant';
  end if;

  raise notice 'ACTIVE_GRANT_ASSIGNMENT_INDEPENDENCE_PASSED';
end;
$$;

do $$
declare
  v_browse oid := to_regprocedure('public.browse_course_offerings(uuid,uuid,uuid,uuid,text)');
  v_snapshot public.discovery_test_snapshot%rowtype;
  v_current_definitions jsonb;
  v_current_acls jsonb;
begin
  select * into strict v_snapshot from public.discovery_test_snapshot;

  if v_browse is null
     or not (select prosecdef from pg_proc where oid = v_browse)
     or (select provolatile from pg_proc where oid = v_browse) <> 's' then
    raise exception 'SECURITY-18A: browse RPC lost SECURITY DEFINER or STABLE metadata';
  end if;

  if not exists (
    select 1
    from pg_proc
    cross join lateral pg_options_to_table(proconfig) option
    where pg_proc.oid = v_browse
      and option.option_name = 'search_path'
      and option.option_value = '""'
  ) then
    raise exception 'SECURITY-18B: browse RPC search_path is not empty';
  end if;

  if not has_function_privilege('authenticated', v_browse, 'EXECUTE')
     or has_function_privilege('anon', v_browse, 'EXECUTE')
     or exists (
       select 1
       from aclexplode(coalesce(
         (select proacl from pg_proc where oid = v_browse),
         acldefault('f', (select proowner from pg_proc where oid = v_browse))
       )) acl
       where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
     ) then
    raise exception 'SECURITY-18C: browse RPC EXECUTE grants changed';
  end if;

  select jsonb_object_agg(signature, pg_get_functiondef(to_regprocedure(signature)))
  into v_current_definitions
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
  ) functions(signature);

  if v_current_definitions is distinct from v_snapshot.protected_function_definitions then
    raise exception 'REGRESSION-20: protected function definition changed';
  end if;

  select jsonb_object_agg(c.oid::regclass::text, coalesce(c.relacl::text, '<default>'))
  into v_current_acls
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind in ('r', 'p');

  if v_current_acls is distinct from v_snapshot.table_acls then
    raise exception 'SECURITY-19A: table ACLs changed during target migration';
  end if;

  if exists (
    select 1
    from (values ('anon'::text), ('authenticated'::text)) roles(name)
    cross join (values
      ('course_offerings'::text),
      ('course_offering_departments'::text),
      ('course_access_grants'::text),
      ('practice_sets'::text)
    ) tables(name)
    where has_table_privilege(roles.name, 'public.' || tables.name, 'INSERT')
       or has_table_privilege(roles.name, 'public.' || tables.name, 'UPDATE')
       or has_table_privilege(roles.name, 'public.' || tables.name, 'DELETE')
  ) then
    raise exception 'SECURITY-19B: browser role has protected-table mutation privilege';
  end if;

  raise notice 'SECURITY_AND_FUNCTION_REGRESSION_PASSED';
end;
$$;

select 'ASSIGNMENT_FREE_DISCOVERY_RUNTIME_MATRIX_PASSED' as result;
