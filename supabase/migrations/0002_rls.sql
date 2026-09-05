-- =============================================================================
-- 0002_rls.sql
-- Row Level Security. This file is the app's actual security boundary --
-- read it carefully before changing anything here.
--
-- General shape used throughout:
--   * "curriculum content is public to any signed-in user" (units/lessons/
--     items) -- select only, mutation is teacher-only.
--   * "a student can only ever see/act on their own rows".
--   * "a parent can see/act on rows belonging to students in
--     parent_children for them".
--   * "a teacher can see rows belonging to students whose profiles.class_id
--     points at a class that teacher owns".
--   * Ledger-ish tables (points_transactions, and to a lesser extent
--     learn_completions / assessment_attempts) grant NO insert/update
--     policy to `authenticated` at all -- the only way to add rows is
--     through the SECURITY DEFINER functions in 0003_functions.sql, which
--     run as the table owner and therefore bypass RLS. This is what stops a
--     student from e.g. inserting a fake points_transactions row worth a
--     million points, or an assessment_attempts row claiming is_correct.
-- =============================================================================

alter table public.profiles            enable row level security;
alter table public.classes             enable row level security;
alter table public.class_students      enable row level security;
alter table public.parent_children     enable row level security;
alter table public.curriculum_units    enable row level security;
alter table public.lessons             enable row level security;
alter table public.lesson_items        enable row level security;
alter table public.learn_completions   enable row level security;
alter table public.assessment_attempts enable row level security;
alter table public.points_transactions enable row level security;
alter table public.rewards             enable row level security;
alter table public.reward_redemptions  enable row level security;

-- Small helper predicates, expressed inline via EXISTS rather than as SQL
-- functions, to keep the policies self-contained and easy to audit; they
-- are repeated verbatim across policies so future readers don't have to
-- chase a function definition to know what a policy actually allows.

-- =============================================================================
-- profiles
-- =============================================================================

-- Everyone can read their own profile.
create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = auth.uid());

-- A parent can read the profiles of their linked children.
create policy profiles_select_parent_children on public.profiles
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = profiles.id
        and pc.parent_id = auth.uid()
    )
  );

-- A teacher can read the profiles of students in a class they own.
create policy profiles_select_teacher_students on public.profiles
  for select to authenticated
  using (
    exists (
      select 1 from public.class_students cs
      join public.classes c on c.id = cs.class_id
      where cs.student_id = profiles.id
        and c.teacher_id = auth.uid()
    )
  );

-- The handle_new_user() trigger (SECURITY DEFINER) is what actually creates
-- profile rows on sign-up and bypasses RLS to do it. This policy is a
-- narrow fallback allowing a signed-in user to insert *their own* row only
-- (id must equal their own uid), in case a client ever needs to upsert its
-- own profile directly.
create policy profiles_insert_self on public.profiles
  for insert to authenticated
  with check (id = auth.uid());

-- A user may update their own profile (name/avatar). Note this technically
-- also allows a user to edit their own `role`/`class_id` -- acceptable for
-- an MVP, but flagged here: if role/class_id need to become
-- teacher/admin-only fields, split this into a column-level check or a
-- dedicated RPC.
create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- =============================================================================
-- classes
-- =============================================================================

create policy classes_select_teacher_owns on public.classes
  for select to authenticated
  using (teacher_id = auth.uid());

create policy classes_select_student_member on public.classes
  for select to authenticated
  using (
    exists (
      select 1 from public.class_students cs
      where cs.class_id = classes.id
        and cs.student_id = auth.uid()
    )
  );

create policy classes_select_parent_of_member on public.classes
  for select to authenticated
  using (
    exists (
      select 1
      from public.parent_children pc
      join public.class_students cs on cs.student_id = pc.student_id
      where pc.parent_id = auth.uid()
        and cs.class_id = classes.id
    )
  );

-- Only a teacher can create/manage classes, and only their own.
create policy classes_insert_teacher on public.classes
  for insert to authenticated
  with check (teacher_id = auth.uid());

create policy classes_update_teacher_owns on public.classes
  for update to authenticated
  using (teacher_id = auth.uid())
  with check (teacher_id = auth.uid());

create policy classes_delete_teacher_owns on public.classes
  for delete to authenticated
  using (teacher_id = auth.uid());

-- =============================================================================
-- class_students
-- Roster membership. Readable by the teacher who owns the class, the
-- student themself, and any parent linked to that student. Only the owning
-- teacher can manage roster membership (enroll/remove students).
-- =============================================================================

create policy class_students_select_teacher on public.class_students
  for select to authenticated
  using (
    exists (
      select 1 from public.classes c
      where c.id = class_students.class_id
        and c.teacher_id = auth.uid()
    )
  );

create policy class_students_select_self on public.class_students
  for select to authenticated
  using (student_id = auth.uid());

create policy class_students_select_parent on public.class_students
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = class_students.student_id
        and pc.parent_id = auth.uid()
    )
  );

create policy class_students_write_teacher on public.class_students
  for all to authenticated
  using (
    exists (
      select 1 from public.classes c
      where c.id = class_students.class_id
        and c.teacher_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.classes c
      where c.id = class_students.class_id
        and c.teacher_id = auth.uid()
    )
  );

-- =============================================================================
-- parent_children
-- Deliberately NO insert/update/delete policy for `authenticated`: linking
-- a parent to a student is a trust boundary that should be established by a
-- verified/admin process (service role), not something any signed-in parent
-- can self-assert for an arbitrary student id. Enabling RLS with zero
-- write policies means all client-side writes are denied by default while
-- an admin using the service-role key can still manage rows freely.
-- =============================================================================

create policy parent_children_select_parent on public.parent_children
  for select to authenticated
  using (parent_id = auth.uid());

create policy parent_children_select_student on public.parent_children
  for select to authenticated
  using (student_id = auth.uid());

-- =============================================================================
-- curriculum_units / lessons / lesson_items
-- Public learning content: any authenticated user (student, parent, or
-- teacher) can read it. Only teachers may write it.
-- =============================================================================

create policy curriculum_units_select_all on public.curriculum_units
  for select to authenticated
  using (true);

create policy curriculum_units_write_teacher on public.curriculum_units
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'));

create policy lessons_select_all on public.lessons
  for select to authenticated
  using (true);

create policy lessons_write_teacher on public.lessons
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'));

create policy lesson_items_select_all on public.lesson_items
  for select to authenticated
  using (true);

create policy lesson_items_write_teacher on public.lesson_items
  for all to authenticated
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'teacher'));

-- =============================================================================
-- learn_completions
-- No INSERT policy for `authenticated` on purpose: rows are only ever
-- created via record_learn_completion() (SECURITY DEFINER), which both
-- enforces the "first completion only earns points" rule and stops a
-- client from back-dating/forging completions for arbitrary students.
-- =============================================================================

create policy learn_completions_select_self on public.learn_completions
  for select to authenticated
  using (student_id = auth.uid());

create policy learn_completions_select_parent on public.learn_completions
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = learn_completions.student_id
        and pc.parent_id = auth.uid()
    )
  );

create policy learn_completions_select_teacher on public.learn_completions
  for select to authenticated
  using (
    exists (
      select 1 from public.class_students cs
      join public.classes c on c.id = cs.class_id
      where cs.student_id = learn_completions.student_id
        and c.teacher_id = auth.uid()
    )
  );

-- =============================================================================
-- assessment_attempts
-- Same rationale as learn_completions: no client INSERT policy, everything
-- goes through record_assessment_attempt().
-- =============================================================================

create policy assessment_attempts_select_self on public.assessment_attempts
  for select to authenticated
  using (student_id = auth.uid());

create policy assessment_attempts_select_parent on public.assessment_attempts
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = assessment_attempts.student_id
        and pc.parent_id = auth.uid()
    )
  );

create policy assessment_attempts_select_teacher on public.assessment_attempts
  for select to authenticated
  using (
    exists (
      select 1 from public.class_students cs
      join public.classes c on c.id = cs.class_id
      where cs.student_id = assessment_attempts.student_id
        and c.teacher_id = auth.uid()
    )
  );

-- =============================================================================
-- points_transactions
-- Read-only for everyone, always. No INSERT/UPDATE/DELETE policy exists for
-- `authenticated` at all -- the ledger can only be appended to by the
-- SECURITY DEFINER functions (record_learn_completion,
-- record_assessment_attempt, redeem_reward, and the reward-rejection
-- refund trigger), which run with elevated privilege and bypass RLS. This
-- is the single most important invariant in the whole schema: a client can
-- never write an arbitrary points delta for itself or anyone else.
-- =============================================================================

create policy points_transactions_select_self on public.points_transactions
  for select to authenticated
  using (student_id = auth.uid());

create policy points_transactions_select_parent on public.points_transactions
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = points_transactions.student_id
        and pc.parent_id = auth.uid()
    )
  );

create policy points_transactions_select_teacher on public.points_transactions
  for select to authenticated
  using (
    exists (
      select 1 from public.class_students cs
      join public.classes c on c.id = cs.class_id
      where cs.student_id = points_transactions.student_id
        and c.teacher_id = auth.uid()
    )
  );

-- =============================================================================
-- rewards
-- A parent manages (CRUD) only the rewards they authored. A student can see
-- only the *active* rewards created FOR THEM SPECIFICALLY (rewards.student_id
-- = auth.uid()) -- rewards are per-child, not a shared family catalog (see
-- the design note on the rewards table in 0001_init.sql), so a student
-- never sees a sibling's rewards.
-- =============================================================================

create policy rewards_select_parent_owns on public.rewards
  for select to authenticated
  using (parent_id = auth.uid());

create policy rewards_select_own_student on public.rewards
  for select to authenticated
  using (active = true and student_id = auth.uid());

create policy rewards_write_parent_owns on public.rewards
  for all to authenticated
  using (parent_id = auth.uid())
  with check (parent_id = auth.uid());

-- =============================================================================
-- reward_redemptions
-- No INSERT policy for `authenticated`: a redemption can only be created
-- via redeem_reward() (SECURITY DEFINER), which validates the reward
-- belongs to a parent linked to the calling student and atomically deducts
-- points. UPDATE is allowed only for the parent who linked to that student,
-- and only they may transition status (approve/reject/fulfill) -- see the
-- refund trigger in 0003_functions.sql for what happens on 'rejected'.
-- =============================================================================

create policy reward_redemptions_select_self on public.reward_redemptions
  for select to authenticated
  using (student_id = auth.uid());

create policy reward_redemptions_select_parent on public.reward_redemptions
  for select to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = reward_redemptions.student_id
        and pc.parent_id = auth.uid()
    )
  );

create policy reward_redemptions_update_parent on public.reward_redemptions
  for update to authenticated
  using (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = reward_redemptions.student_id
        and pc.parent_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.parent_children pc
      where pc.student_id = reward_redemptions.student_id
        and pc.parent_id = auth.uid()
    )
  );
