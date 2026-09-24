begin;

create function public.admin_transition_practice_set(
  p_practice_set_id uuid,
  p_expected_current_status text,
  p_new_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_course_offering_id uuid;
  v_current_status text;
  v_updated_status text;
  v_reason text;
  v_requires_readiness boolean;
  v_readiness jsonb := null;
  v_readiness_warning_codes jsonb;
  v_audit_event_id uuid;
begin
  perform public.assert_admin();

  select
    practice_sets.course_offering_id,
    practice_sets.status
  into
    v_course_offering_id,
    v_current_status
  from public.practice_sets
  where practice_sets.id = p_practice_set_id
  for update;

  if not found then
    raise exception 'Practice Set % was not found', p_practice_set_id
      using errcode = 'P0002';
  end if;

  if p_expected_current_status is null then
    raise exception 'Expected current Practice Set status is required'
      using errcode = '22023';
  end if;

  if p_new_status is null then
    raise exception 'New Practice Set status is required'
      using errcode = '22023';
  end if;

  if v_current_status is distinct from p_expected_current_status then
    raise exception 'Practice Set status changed: expected %, found %',
      p_expected_current_status,
      v_current_status
      using errcode = '40001';
  end if;

  if v_current_status is not distinct from p_new_status then
    raise exception 'Practice Set is already in status %', v_current_status
      using errcode = '22023';
  end if;

  if not (
    (v_current_status = 'draft' and p_new_status = 'review')
    or (v_current_status = 'review' and p_new_status = 'draft')
    or (v_current_status = 'review' and p_new_status = 'published')
    or (v_current_status = 'published' and p_new_status = 'archived')
  ) then
    raise exception 'Practice Set transition from % to % is not supported',
      v_current_status,
      p_new_status
      using errcode = '22023';
  end if;

  v_reason := case
    when p_reason is null then null
    else nullif(pg_catalog.btrim(p_reason, E' \t\n\r\f\v'), '')
  end;

  if (
    (v_current_status = 'review' and p_new_status = 'draft')
    or (v_current_status = 'published' and p_new_status = 'archived')
  ) and v_reason is null then
    raise exception 'A nonblank reason is required for the Practice Set transition from % to %',
      v_current_status,
      p_new_status
      using errcode = '22023';
  end if;

  v_requires_readiness := (
    (v_current_status = 'draft' and p_new_status = 'review')
    or (v_current_status = 'review' and p_new_status = 'published')
  );

  if v_requires_readiness then
    v_readiness := public.evaluate_practice_set_readiness(
      p_practice_set_id
    );

    if not coalesce((v_readiness ->> 'is_ready')::boolean, false) then
      raise exception 'Practice Set % is not ready for transition from % to %',
        p_practice_set_id,
        v_current_status,
        p_new_status
        using
          errcode = '23514',
          detail = v_readiness::text;
    end if;

    select coalesce(
      pg_catalog.jsonb_agg(
        readiness_warning.warning ->> 'code'
        order by readiness_warning.ordinality
      ),
      '[]'::jsonb
    )
    into v_readiness_warning_codes
    from pg_catalog.jsonb_array_elements(
      v_readiness -> 'warnings'
    ) with ordinality as readiness_warning(warning, ordinality);
  end if;

  update public.practice_sets
  set status = p_new_status
  where practice_sets.id = p_practice_set_id
    and practice_sets.status = p_expected_current_status
  returning practice_sets.status into v_updated_status;

  if not found then
    raise exception 'Practice Set % status mutation did not update exactly one row',
      p_practice_set_id
      using errcode = '40001';
  end if;

  v_audit_event_id := public.record_admin_audit_event(
    p_action => 'practice_set.lifecycle_transition',
    p_target_entity_type => 'practice_set',
    p_target_entity_id => p_practice_set_id,
    p_reason => v_reason,
    p_metadata => case
      when v_requires_readiness then
        pg_catalog.jsonb_build_object(
          'course_offering_id', v_course_offering_id,
          'previous_status', v_current_status,
          'new_status', v_updated_status,
          'readiness_is_ready', v_readiness -> 'is_ready',
          'readiness_summary', v_readiness -> 'summary',
          'readiness_warning_codes', v_readiness_warning_codes
        )
      else
        pg_catalog.jsonb_build_object(
          'course_offering_id', v_course_offering_id,
          'previous_status', v_current_status,
          'new_status', v_updated_status
        )
    end
  );

  return pg_catalog.jsonb_build_object(
    'practice_set_id', p_practice_set_id,
    'course_offering_id', v_course_offering_id,
    'previous_status', v_current_status,
    'new_status', v_updated_status,
    'audit_event_id', v_audit_event_id,
    'readiness', v_readiness
  );
end;
$$;

comment on function public.admin_transition_practice_set(uuid, text, text, text) is
  'Admin-only Practice Set lifecycle transition with row locking, readiness gates, and atomic append-only audit.';

revoke all on function public.admin_transition_practice_set(uuid, text, text, text)
from PUBLIC, anon, authenticated;

grant execute on function public.admin_transition_practice_set(uuid, text, text, text)
to authenticated;

commit;
