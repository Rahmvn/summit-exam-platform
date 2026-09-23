begin;

create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  full_name text,
  matric_number text,
  department_id uuid references public.departments (id) on delete restrict,
  level_id uuid references public.levels (id) on delete restrict,
  current_semester_id uuid references public.semesters (id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_matric_number_key unique (matric_number),
  constraint profiles_full_name_nonempty_check check (
    full_name is null or btrim(full_name) <> ''
  ),
  constraint profiles_matric_number_format_check check (
    matric_number is null
    or (
      btrim(matric_number) <> ''
      and matric_number = upper(btrim(matric_number))
    )
  )
);

create index profiles_department_id_idx
  on public.profiles (department_id);

create index profiles_level_id_idx
  on public.profiles (level_id);

create index profiles_current_semester_id_idx
  on public.profiles (current_semester_id);

create function public.normalize_profile_fields()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.full_name is not null then
    new.full_name := btrim(
      regexp_replace(new.full_name, '[[:space:]]+', ' ', 'g')
    );

    if new.full_name = lower(new.full_name)
      or new.full_name = upper(new.full_name) then
      new.full_name := initcap(new.full_name);
    end if;
  end if;

  if new.matric_number is not null then
    new.matric_number := upper(btrim(new.matric_number));
  end if;

  return new;
end;
$$;

create trigger normalize_profile_fields
before insert or update of full_name, matric_number on public.profiles
for each row
execute function public.normalize_profile_fields();

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

alter table public.profiles enable row level security;

revoke all on table public.profiles from PUBLIC, anon, authenticated;
revoke all on function public.normalize_profile_fields() from PUBLIC, anon, authenticated;
revoke all on function public.set_updated_at() from PUBLIC, anon, authenticated;

grant select on table public.profiles to authenticated;

grant insert (
  user_id,
  full_name,
  matric_number,
  department_id,
  level_id,
  current_semester_id
) on public.profiles to authenticated;

grant update (
  full_name,
  matric_number,
  department_id,
  level_id,
  current_semester_id
) on public.profiles to authenticated;

create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

commit;
