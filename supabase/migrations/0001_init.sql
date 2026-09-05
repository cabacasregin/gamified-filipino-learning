-- =============================================================================
-- 0001_init.sql
-- Core schema for the gamified Filipino-learning platform.
--
-- Design notes (things not fully pinned down by the product brief):
--
-- * Class membership: a `class_students` join table (class_id, student_id)
--   links students to classes. It carries a UNIQUE constraint on
--   student_id, so in practice each student still belongs to at most one
--   class at a time (matches "keep the class model simple") -- but the
--   shape is a normal many-to-many join table rather than a column on
--   profiles, for consistency with the client's expected table name.
--
-- * lesson_items carry BOTH `lesson_id` (the real hierarchy edge,
--   curriculum_units -> lessons -> lesson_items) and a denormalized
--   `unit_id` (requested explicitly in the brief for lesson_item). `unit_id`
--   is kept in sync automatically by a trigger (see below) so it can never
--   drift from `lesson_id`'s parent unit. This gives cheap "all items in
--   this unit" queries without a join, while lesson_id remains the source
--   of truth for ordering/structure.
--
-- * Money-like fields (points) are always plain integers, never floats.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Extensions
-- ---------------------------------------------------------------------------
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "citext";     -- case-insensitive text (emails, matching)

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('student', 'teacher', 'parent');

-- Where a points ledger row came from.
create type public.points_source_type as enum ('learn', 'assessment', 'reward_redeem');

-- Lifecycle of a reward redemption request.
create type public.redemption_status as enum ('pending', 'approved', 'fulfilled', 'rejected');

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- One trigger function reused by every table that has an `updated_at`
-- column, so "last modified" is always accurate without relying on the
-- client to set it.
-- ---------------------------------------------------------------------------
create function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- classes  (created before profiles/class_students so they can reference it)
-- ---------------------------------------------------------------------------
create table public.classes (
  id          uuid primary key default gen_random_uuid(),
  teacher_id  uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.classes is
  'A roster a teacher manages. Students are attached via class_students.';

create index classes_teacher_id_idx on public.classes(teacher_id);

create trigger classes_set_updated_at
  before update on public.classes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- profiles
-- One row per auth.users row. Created automatically by the
-- handle_new_user() trigger below (see the trigger on auth.users), driven by
-- `raw_user_meta_data` supplied at sign-up (e.g. `{ "role": "teacher",
-- "full_name": "..." }`). Defaults to role = 'student' if none is supplied.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        public.user_role not null default 'student',
  full_name   text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index profiles_role_idx on public.profiles(role);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- class_students
-- Join table linking a class to its enrolled students. UNIQUE(student_id)
-- keeps "a student belongs to at most one class" as an enforced invariant
-- (see design note at the top of this file) while still giving the client
-- the many-to-many table shape it expects.
-- ---------------------------------------------------------------------------
create table public.class_students (
  class_id    uuid not null references public.classes(id) on delete cascade,
  student_id  uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (class_id, student_id),
  unique (student_id)
);

create index class_students_class_id_idx on public.class_students(class_id);

-- Auto-provision a profile row whenever a new auth user is created.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, role, full_name)
  values (
    new.id,
    coalesce((new.raw_user_meta_data->>'role')::public.user_role, 'student'),
    new.raw_user_meta_data->>'full_name'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- parent_children
-- Links a parent account to one or more student accounts. Intentionally has
-- no self-service INSERT policy (see 0002_rls.sql) -- linking a parent to a
-- student is a trust boundary (anyone could otherwise "claim" a child), so
-- for this MVP rows are created by an administrator / service-role process.
-- A verified invite-code flow can add self-service linking later without
-- changing this table's shape.
-- ---------------------------------------------------------------------------
create table public.parent_children (
  parent_id   uuid not null references auth.users(id) on delete cascade,
  student_id  uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (parent_id, student_id)
);

create index parent_children_student_id_idx on public.parent_children(student_id);

-- ---------------------------------------------------------------------------
-- curriculum_units -> lessons -> lesson_items
-- ---------------------------------------------------------------------------
create table public.curriculum_units (
  id          uuid primary key default gen_random_uuid(),
  title_en    text not null,          -- e.g. "Filipino Alphabet"
  title_fil   text not null,          -- e.g. "Alpabetong Filipino"
  slug        text not null unique,   -- e.g. "alpabetong-filipino"
  -- Short blurb shown on the unit card in both the student app and the CMS
  -- edit form, e.g. "Learn the modern Filipino alphabet".
  description text,
  -- Single emoji shown large on the student's unit-picker card. Defaults to
  -- a generic book so a unit created without one still renders sensibly.
  icon_emoji  text not null default '📘',
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index curriculum_units_sort_order_idx on public.curriculum_units(sort_order);

create trigger curriculum_units_set_updated_at
  before update on public.curriculum_units
  for each row execute function public.set_updated_at();

create table public.lessons (
  id          uuid primary key default gen_random_uuid(),
  unit_id     uuid not null references public.curriculum_units(id) on delete cascade,
  title       text not null,
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index lessons_unit_id_idx on public.lessons(unit_id);
create index lessons_sort_order_idx on public.lessons(unit_id, sort_order);

create trigger lessons_set_updated_at
  before update on public.lessons
  for each row execute function public.set_updated_at();

create table public.lesson_items (
  id                 uuid primary key default gen_random_uuid(),
  lesson_id          uuid not null references public.lessons(id) on delete cascade,
  -- Denormalized copy of lessons.unit_id, auto-maintained -- see
  -- sync_lesson_item_unit_id() below. Lets the app query "all items in unit
  -- X" without joining through lessons.
  unit_id            uuid not null references public.curriculum_units(id) on delete cascade,
  english_text       text not null,
  filipino_text      text not null,
  -- Short human-readable phonetic hint, e.g. "ee-SAH", purely informational.
  phonetic_hint      text,
  -- Alternate accepted spellings / common ASR mis-transcriptions that should
  -- still count as a correct spoken answer, e.g. {"isa","isang","eesa"}.
  accepted_variants  text[] not null default '{}',
  emoji              text,          -- e.g. 'A' -> a representative emoji is not always possible; used for numbers/shapes/colors
  image_url          text,          -- nullable placeholder for a future real image asset
  -- Override for client-side TTS when the raw filipino_text would not be
  -- pronounced correctly as-is (e.g. needs syllable stress marks).
  tts_locale         text not null default 'fil-PH',
  tts_text           text,          -- null = use filipino_text verbatim
  sort_order         integer not null default 0,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index lesson_items_lesson_id_idx on public.lesson_items(lesson_id);
create index lesson_items_unit_id_idx on public.lesson_items(unit_id);
create index lesson_items_sort_order_idx on public.lesson_items(lesson_id, sort_order);

create trigger lesson_items_set_updated_at
  before update on public.lesson_items
  for each row execute function public.set_updated_at();

-- Keep lesson_items.unit_id in lockstep with its parent lesson's unit_id,
-- regardless of what the client sends (or if lesson_id is later moved to a
-- different unit's lesson).
create function public.sync_lesson_item_unit_id()
returns trigger
language plpgsql
as $$
begin
  select unit_id into new.unit_id from public.lessons where id = new.lesson_id;
  if new.unit_id is null then
    raise exception 'lesson_id % does not reference an existing lesson', new.lesson_id;
  end if;
  return new;
end;
$$;

create trigger lesson_items_sync_unit_id
  before insert or update of lesson_id on public.lesson_items
  for each row execute function public.sync_lesson_item_unit_id();

-- ---------------------------------------------------------------------------
-- learn_completions
-- One row per (student, lesson_item) the first time "learn" mode is
-- completed. The unique constraint is what makes record_learn_completion()
-- idempotent (see 0003_functions.sql).
-- ---------------------------------------------------------------------------
create table public.learn_completions (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references auth.users(id) on delete cascade,
  lesson_item_id  uuid not null references public.lesson_items(id) on delete cascade,
  completed_at    timestamptz not null default now(),
  unique (student_id, lesson_item_id)
);

create index learn_completions_student_id_idx on public.learn_completions(student_id);
create index learn_completions_lesson_item_id_idx on public.learn_completions(lesson_item_id);

-- ---------------------------------------------------------------------------
-- assessment_attempts
-- Every spoken-answer attempt, correct or not. Append-only audit trail;
-- points_awarded is computed and frozen at insert time by
-- record_assessment_attempt() so historical rows never change even if the
-- points formula changes later.
-- ---------------------------------------------------------------------------
create table public.assessment_attempts (
  id              uuid primary key default gen_random_uuid(),
  student_id      uuid not null references auth.users(id) on delete cascade,
  lesson_item_id  uuid not null references public.lesson_items(id) on delete cascade,
  transcript      text not null,
  is_correct      boolean not null,
  points_awarded  integer not null default 0,
  attempted_at    timestamptz not null default now()
);

create index assessment_attempts_student_item_idx
  on public.assessment_attempts(student_id, lesson_item_id);
create index assessment_attempts_attempted_at_idx on public.assessment_attempts(attempted_at);

-- ---------------------------------------------------------------------------
-- points_transactions
-- The single ledger of truth for a student's points. Never write directly
-- from the client -- rows are only ever inserted by the SECURITY DEFINER
-- functions in 0003_functions.sql, which is why there is no INSERT/UPDATE
-- policy granted to `authenticated` on this table (see 0002_rls.sql).
-- ---------------------------------------------------------------------------
create table public.points_transactions (
  id           uuid primary key default gen_random_uuid(),
  student_id   uuid not null references auth.users(id) on delete cascade,
  source_type  public.points_source_type not null,
  -- Polymorphic pointer to whatever row caused this transaction
  -- (lesson_items.id for learn/assessment, reward_redemptions.id for
  -- reward_redeem). Not a foreign key since it targets different tables.
  source_id    uuid,
  delta        integer not null,
  note         text,
  created_at   timestamptz not null default now()
);

create index points_transactions_student_id_idx
  on public.points_transactions(student_id, created_at);

-- ---------------------------------------------------------------------------
-- student_points_balance
-- Simple sum-of-ledger view. A view (not a materialized view) so the
-- balance is always exact and never needs a refresh job -- point volumes
-- for a learning app are small enough that summing on read is cheap.
--
-- security_invoker = true is NOT optional here: without it, a view owned by
-- the migration role (postgres, which has BYPASSRLS) would evaluate the
-- underlying points_transactions RLS policies using the OWNER's privileges
-- rather than the querying user's, silently exposing every student's
-- balance to any authenticated caller. With security_invoker, the view is
-- re-checked against points_transactions' own RLS policies (self / parent /
-- teacher) for whoever is actually running the query, exactly like
-- querying the table directly.
-- ---------------------------------------------------------------------------
create view public.student_points_balance
  with (security_invoker = true)
as
select
  student_id,
  coalesce(sum(delta), 0)::integer as balance
from public.points_transactions
group by student_id;

comment on view public.student_points_balance is
  'Current point balance per student, derived from points_transactions. A student with no transactions simply has no row (treat missing = 0). security_invoker=true so RLS is enforced per-caller.';

grant select on public.student_points_balance to authenticated;

-- ---------------------------------------------------------------------------
-- rewards
-- Defined by a parent for ONE specific child (student_id) -- "parents
-- define rewards for their own children" is modeled as a per-child reward,
-- not a shared family pool, since the client expects a student_id column
-- here. The validate_reward_student_link() trigger below is what stops a
-- parent from creating a reward against a student who isn't actually their
-- linked child (a plain FK can't express that cross-table check).
-- ---------------------------------------------------------------------------
create table public.rewards (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid not null references auth.users(id) on delete cascade,
  student_id   uuid not null references auth.users(id) on delete cascade,
  name         text not null,
  description  text,
  point_cost   integer not null check (point_cost > 0),
  icon         text,   -- emoji, e.g. '🍦'
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index rewards_parent_id_idx on public.rewards(parent_id);
create index rewards_student_id_idx on public.rewards(student_id);
create index rewards_active_idx on public.rewards(student_id, active);

create trigger rewards_set_updated_at
  before update on public.rewards
  for each row execute function public.set_updated_at();

create function public.validate_reward_student_link()
returns trigger
language plpgsql
as $$
begin
  if not exists (
    select 1 from public.parent_children pc
    where pc.parent_id = new.parent_id
      and pc.student_id = new.student_id
  ) then
    raise exception 'student % is not a linked child of parent %', new.student_id, new.parent_id;
  end if;
  return new;
end;
$$;

create trigger rewards_validate_student_link
  before insert or update of parent_id, student_id on public.rewards
  for each row execute function public.validate_reward_student_link();

-- ---------------------------------------------------------------------------
-- reward_redemptions
-- Redemption flow chosen (documented in full in 0003_functions.sql, next to
-- redeem_reward()): points are DEDUCTED AT REQUEST TIME (status='pending'),
-- and REFUNDED automatically if a parent rejects the request. `points_spent`
-- freezes the cost at request time so a later change to rewards.point_cost
-- can never corrupt the refund amount.
-- ---------------------------------------------------------------------------
create table public.reward_redemptions (
  id            uuid primary key default gen_random_uuid(),
  student_id    uuid not null references auth.users(id) on delete cascade,
  reward_id     uuid not null references public.rewards(id) on delete cascade,
  status        public.redemption_status not null default 'pending',
  points_spent  integer not null,
  requested_at  timestamptz not null default now(),
  decided_at    timestamptz,
  decided_by    uuid references auth.users(id),
  note          text
);

create index reward_redemptions_student_id_idx on public.reward_redemptions(student_id);
create index reward_redemptions_reward_id_idx on public.reward_redemptions(reward_id);
create index reward_redemptions_status_idx on public.reward_redemptions(status);
