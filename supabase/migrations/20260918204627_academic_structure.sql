begin;

create table public.colleges (
  id uuid primary key default gen_random_uuid(),
  name text not null check (btrim(name) <> ''),
  code text not null unique check (
    btrim(code) <> '' and code = upper(btrim(code))
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges (id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  code text not null check (
    btrim(code) <> '' and code = upper(btrim(code))
  ),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint departments_college_code_key unique (college_id, code)
);

create table public.levels (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (
    btrim(code) <> '' and code = upper(btrim(code))
  ),
  label text not null check (btrim(label) <> ''),
  sort_order integer not null check (sort_order >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.academic_sessions (
  id uuid primary key default gen_random_uuid(),
  start_year integer not null,
  end_year integer not null,
  label text not null generated always as (
    start_year::text || '/' || end_year::text
  ) stored,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint academic_sessions_years_check check (end_year = start_year + 1),
  constraint academic_sessions_years_key unique (start_year, end_year)
);

create table public.semesters (
  id uuid primary key default gen_random_uuid(),
  academic_session_id uuid not null references public.academic_sessions (id) on delete restrict,
  semester_number smallint not null check (semester_number in (1, 2)),
  name text not null generated always as (
    case semester_number
      when 1 then 'First Semester'
      when 2 then 'Second Semester'
    end
  ) stored,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint semesters_session_number_key unique (academic_session_id, semester_number)
);

create table public.courses (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (
    btrim(code) <> '' and code = upper(btrim(code))
  ),
  title text not null check (btrim(title) <> ''),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.course_offerings (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete restrict,
  semester_id uuid not null references public.semesters (id) on delete restrict,
  exam_mode text not null check (exam_mode in ('cbt', 'written')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint course_offerings_course_semester_key unique (course_id, semester_id)
);

create table public.course_offering_departments (
  course_offering_id uuid not null references public.course_offerings (id) on delete restrict,
  department_id uuid not null references public.departments (id) on delete restrict,
  level_id uuid not null references public.levels (id) on delete restrict,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (course_offering_id, department_id, level_id)
);

create index course_offerings_semester_id_idx
  on public.course_offerings (semester_id);

create index course_offering_departments_audience_idx
  on public.course_offering_departments (department_id, level_id, course_offering_id);

insert into public.levels (code, label, sort_order)
values
  ('100', '100 Level', 100),
  ('200', '200 Level', 200),
  ('300', '300 Level', 300),
  ('400', '400 Level', 400),
  ('500', '500 Level', 500);

alter table public.colleges enable row level security;
alter table public.departments enable row level security;
alter table public.levels enable row level security;
alter table public.academic_sessions enable row level security;
alter table public.semesters enable row level security;
alter table public.courses enable row level security;
alter table public.course_offerings enable row level security;
alter table public.course_offering_departments enable row level security;

revoke all on table
  public.colleges,
  public.departments,
  public.levels,
  public.academic_sessions,
  public.semesters,
  public.courses,
  public.course_offerings,
  public.course_offering_departments
from PUBLIC, anon, authenticated;

grant select on table
  public.colleges,
  public.departments,
  public.levels,
  public.academic_sessions,
  public.semesters,
  public.courses,
  public.course_offerings,
  public.course_offering_departments
to anon, authenticated;

create policy "Catalogue entries are publicly readable"
  on public.colleges for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.departments for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.levels for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.academic_sessions for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.semesters for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.courses for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.course_offerings for select
  to anon, authenticated
  using (true);

create policy "Catalogue entries are publicly readable"
  on public.course_offering_departments for select
  to anon, authenticated
  using (true);

commit;
