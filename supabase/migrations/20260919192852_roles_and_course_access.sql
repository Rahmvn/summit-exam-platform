begin;

create table public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.course_access_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  source_type text not null check (
    source_type in ('manual', 'purchase', 'promotion', 'system')
  ),
  granted_by uuid references auth.users (id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users (id) on delete set null,
  revoke_reason text check (
    revoke_reason is null or btrim(revoke_reason) <> ''
  ),
  internal_note text check (
    internal_note is null or btrim(internal_note) <> ''
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint course_access_grants_time_range_check check (
    expires_at > starts_at
  ),
  constraint course_access_grants_revocation_metadata_check check (
    revoked_at is not null
    or (revoked_by is null and revoke_reason is null)
  )
);

create function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.app_admins
    where app_admins.user_id = (select auth.uid())
  );
$$;

create function public.has_active_course_access(p_course_offering_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.course_access_grants
    where course_access_grants.user_id = (select auth.uid())
      and course_access_grants.course_offering_id = p_course_offering_id
      and course_access_grants.revoked_at is null
      and course_access_grants.starts_at <= pg_catalog.now()
      and course_access_grants.expires_at > pg_catalog.now()
  );
$$;

create trigger set_course_access_grants_updated_at
before update on public.course_access_grants
for each row
execute function public.set_updated_at();

create index course_access_grants_active_lookup_idx
  on public.course_access_grants (
    user_id,
    course_offering_id,
    starts_at,
    expires_at
  )
  where revoked_at is null;

create index course_access_grants_course_offering_id_idx
  on public.course_access_grants (course_offering_id);

alter table public.app_admins enable row level security;
alter table public.course_access_grants enable row level security;

revoke all on table public.app_admins
from PUBLIC, anon, authenticated;

revoke all on table public.course_access_grants
from PUBLIC, anon, authenticated;

revoke all on function public.is_admin()
from PUBLIC, anon, authenticated;

revoke all on function public.has_active_course_access(uuid)
from PUBLIC, anon, authenticated;

grant execute on function public.is_admin()
to authenticated;

grant execute on function public.has_active_course_access(uuid)
to authenticated;

commit;
