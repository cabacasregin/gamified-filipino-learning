-- =============================================================================
-- 0003_functions.sql
-- SECURITY DEFINER functions. These are the ONLY way points_transactions,
-- learn_completions, assessment_attempts, and reward_redemptions ever get
-- written from the client -- see 0002_rls.sql for why (no INSERT policy
-- exists on those tables for `authenticated`). Each function runs with the
-- privileges of the function owner (bypassing RLS internally) but always
-- re-derives "who is calling" from auth.uid() and never trusts a
-- caller-supplied student id for its own identity, so a student can never
-- act as another student.
--
-- Points values (chosen, not specified exactly by the brief):
--   LEARN_POINTS               = 2   (low-value, awarded once per item)
--   ASSESSMENT_BASE_POINTS     = 5
--   ASSESSMENT_MULTIPLIER      = 3   -> 15 pts for a first-correct spoken answer
-- =============================================================================

-- ---------------------------------------------------------------------------
-- record_learn_completion(p_lesson_item_id)
-- Marks a lesson item as completed in "learn" mode for the calling student
-- and awards a fixed, low point value -- but only the first time. Idempotent:
-- calling it again for an already-completed item is a no-op (0 points),
-- enforced by learn_completions' UNIQUE(student_id, lesson_item_id).
-- ---------------------------------------------------------------------------
create function public.record_learn_completion(p_lesson_item_id uuid)
returns table (already_completed boolean, points_awarded integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_learn_points constant integer := 2;
  v_inserted boolean := false;
begin
  if v_student_id is null then
    raise exception 'not authenticated';
  end if;

  if not exists (select 1 from public.lesson_items where id = p_lesson_item_id) then
    raise exception 'lesson_item % does not exist', p_lesson_item_id;
  end if;

  insert into public.learn_completions (student_id, lesson_item_id)
  values (v_student_id, p_lesson_item_id)
  on conflict (student_id, lesson_item_id) do nothing;

  v_inserted := found;

  if v_inserted then
    insert into public.points_transactions (student_id, source_type, source_id, delta, note)
    values (v_student_id, 'learn', p_lesson_item_id, v_learn_points, 'Learn-mode completion');

    return query select false, v_learn_points;
  else
    return query select true, 0;
  end if;
end;
$$;

comment on function public.record_learn_completion(uuid) is
  'Awards fixed learn-mode points for the calling student, once per lesson_item. Safe to call repeatedly.';

-- ---------------------------------------------------------------------------
-- record_assessment_attempt(p_lesson_item_id, p_transcript, p_is_correct)
--
-- IMPORTANT: p_is_correct is accepted from the client (e.g. a client-side
-- ASR/matching pass may have an opinion), but it is NOT trusted for scoring.
-- The function independently recomputes correctness itself by comparing the
-- transcript against lesson_items.filipino_text and accepted_variants
-- (case-/whitespace-insensitive). This is what stops a client from simply
-- passing p_is_correct := true to farm points. The client-supplied value is
-- discarded; only the server-computed result is stored and rewarded.
--
-- "Only first-correct-attempt earns points": we check whether the student
-- already has ANY prior correct attempt for this lesson_item; if not, and
-- this attempt is correct, award ASSESSMENT_BASE_POINTS * ASSESSMENT_MULTIPLIER.
-- Every attempt (right or wrong) is still recorded for the audit trail /
-- progress dashboards.
-- ---------------------------------------------------------------------------
create function public.record_assessment_attempt(
  p_lesson_item_id uuid,
  p_transcript text,
  p_is_correct boolean default null -- accepted for API compatibility; ignored for scoring, see comment above
)
returns table (attempt_id uuid, is_correct boolean, points_awarded integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_base_points constant integer := 5;
  v_multiplier constant integer := 3;
  v_filipino_text text;
  v_accepted_variants text[];
  v_normalized_transcript text;
  v_computed_correct boolean;
  v_already_correct boolean;
  v_points integer := 0;
  v_attempt_id uuid;
begin
  if v_student_id is null then
    raise exception 'not authenticated';
  end if;

  select filipino_text, accepted_variants
    into v_filipino_text, v_accepted_variants
    from public.lesson_items
    where id = p_lesson_item_id;

  if not found then
    raise exception 'lesson_item % does not exist', p_lesson_item_id;
  end if;

  v_normalized_transcript := lower(trim(coalesce(p_transcript, '')));

  v_computed_correct :=
    v_normalized_transcript <> ''
    and (
      v_normalized_transcript = lower(trim(v_filipino_text))
      or v_normalized_transcript = any (
        select lower(trim(variant)) from unnest(coalesce(v_accepted_variants, '{}')) as variant
      )
    );

  -- Table alias + column-qualified reference to aa.is_correct is required
  -- here: this function's OUT parameter is also named `is_correct` (see the
  -- `returns table (...)` clause), and PL/pgSQL would otherwise resolve a
  -- bare `is_correct` to that variable instead of the table column.
  select exists (
    select 1 from public.assessment_attempts aa
    where aa.student_id = v_student_id
      and aa.lesson_item_id = p_lesson_item_id
      and aa.is_correct = true
  ) into v_already_correct;

  if v_computed_correct and not v_already_correct then
    v_points := v_base_points * v_multiplier;
  end if;

  insert into public.assessment_attempts (student_id, lesson_item_id, transcript, is_correct, points_awarded)
  values (v_student_id, p_lesson_item_id, p_transcript, v_computed_correct, v_points)
  returning id into v_attempt_id;

  if v_points > 0 then
    insert into public.points_transactions (student_id, source_type, source_id, delta, note)
    values (v_student_id, 'assessment', p_lesson_item_id, v_points, 'First-correct assessment attempt');
  end if;

  return query select v_attempt_id, v_computed_correct, v_points;
end;
$$;

comment on function public.record_assessment_attempt(uuid, text, boolean) is
  'Records a spoken-answer attempt and awards points only on the first server-verified-correct attempt per lesson_item. Correctness is always recomputed server-side; the p_is_correct argument is not trusted.';

-- ---------------------------------------------------------------------------
-- redeem_reward(p_reward_id)
--
-- Redemption flow chosen: points are DEDUCTED AT REQUEST TIME, not at
-- approval time. A row is inserted into reward_redemptions with
-- status='pending' and a matching negative points_transactions row is
-- written atomically in the same transaction. If a parent later REJECTS the
-- request (via a plain UPDATE on reward_redemptions, allowed by RLS), the
-- refund_rejected_redemption() trigger below automatically inserts a
-- compensating positive points_transactions row. Approving/fulfilling a
-- request has no further ledger effect since the deduction already happened.
--
-- Rationale: deduct-at-request prevents a student from spending the same
-- points twice by firing off many pending redemption requests while waiting
-- for approval (their balance drops immediately, so they can't over-request).
--
-- Returns the new reward_redemptions.id (uuid). PostgREST/postgrest-js and
-- the Supabase Dart client both serialize a scalar `uuid` return value as a
-- plain JSON string, so `await supabase.rpc('redeem_reward', ...)` yields a
-- String directly -- no explicit ::text cast needed on this side.
-- ---------------------------------------------------------------------------
create function public.redeem_reward(p_reward_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid := auth.uid();
  v_point_cost integer;
  v_active boolean;
  v_reward_student_id uuid;
  v_balance integer;
  v_redemption_id uuid;
begin
  if v_student_id is null then
    raise exception 'not authenticated';
  end if;

  select point_cost, active, student_id
    into v_point_cost, v_active, v_reward_student_id
    from public.rewards
    where id = p_reward_id;

  if not found then
    raise exception 'reward % does not exist', p_reward_id;
  end if;

  if v_reward_student_id <> v_student_id then
    raise exception 'reward % is not available to this student', p_reward_id;
  end if;

  if not v_active then
    raise exception 'reward % is not currently active', p_reward_id;
  end if;

  select coalesce(sum(delta), 0) into v_balance
    from public.points_transactions
    where student_id = v_student_id;

  if v_balance < v_point_cost then
    raise exception 'insufficient points balance: have %, need %', v_balance, v_point_cost;
  end if;

  insert into public.reward_redemptions (student_id, reward_id, status, points_spent)
  values (v_student_id, p_reward_id, 'pending', v_point_cost)
  returning id into v_redemption_id;

  insert into public.points_transactions (student_id, source_type, source_id, delta, note)
  values (v_student_id, 'reward_redeem', v_redemption_id, -v_point_cost, 'Reward redemption requested');

  return v_redemption_id;
end;
$$;

comment on function public.redeem_reward(uuid) is
  'Deducts points immediately and creates a pending redemption request. Rejection refunds automatically via refund_rejected_redemption trigger.';

-- ---------------------------------------------------------------------------
-- decided_at / decided_by bookkeeping + rejection refund
-- A parent transitions reward_redemptions.status via a plain UPDATE
-- (allowed by RLS in 0002_rls.sql). These triggers keep the audit fields
-- honest and implement the refund half of the redemption flow described
-- above.
-- ---------------------------------------------------------------------------
create function public.stamp_reward_redemption_decision()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status and old.status = 'pending' then
    new.decided_at := now();
    new.decided_by := auth.uid();
  end if;
  return new;
end;
$$;

create trigger reward_redemptions_stamp_decision
  before update on public.reward_redemptions
  for each row execute function public.stamp_reward_redemption_decision();

create function public.refund_rejected_redemption()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'rejected' and old.status is distinct from 'rejected' then
    insert into public.points_transactions (student_id, source_type, source_id, delta, note)
    values (new.student_id, 'reward_redeem', new.id, new.points_spent, 'Refund for rejected reward redemption');
  end if;
  return new;
end;
$$;

create trigger reward_redemptions_refund_on_reject
  after update on public.reward_redemptions
  for each row execute function public.refund_rejected_redemption();

-- ---------------------------------------------------------------------------
-- student_unit_mastery(p_student_id)
-- Backs the teacher/parent progress dashboards: per curriculum_unit, how
-- many lesson_items exist, how many the student has ever attempted in
-- assessment mode, how many of those they have EVER gotten correct at least
-- once (not "most recent attempt correct" -- a student who eventually gets
-- an item right counts as having mastered it, even if an earlier attempt on
-- the same item was wrong), and the resulting accuracy.
--
-- accuracy = correct_count / attempted_count, or NULL if nothing attempted
-- yet (avoids a misleading 0% for units the student hasn't started).
--
-- Access control mirrors the RLS predicates used elsewhere: a caller may
-- only query mastery for themself, a linked child, or a student in a class
-- they teach.
-- ---------------------------------------------------------------------------
create function public.student_unit_mastery(p_student_id uuid)
returns table (
  unit_id uuid,
  unit_title text,
  total_items integer,
  attempted_count integer,
  correct_count integer,
  accuracy numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not (
    p_student_id = auth.uid()
    or exists (
      select 1 from public.parent_children pc
      where pc.parent_id = auth.uid() and pc.student_id = p_student_id
    )
    or exists (
      select 1 from public.class_students cs
      join public.classes c on c.id = cs.class_id
      where cs.student_id = p_student_id and c.teacher_id = auth.uid()
    )
  ) then
    raise exception 'not authorized to view mastery for student %', p_student_id;
  end if;

  return query
  with item_stats as (
    select
      li.id as lesson_item_id,
      li.unit_id as u_id,
      exists (
        select 1 from public.assessment_attempts a
        where a.lesson_item_id = li.id and a.student_id = p_student_id
      ) as attempted,
      exists (
        select 1 from public.assessment_attempts a
        where a.lesson_item_id = li.id and a.student_id = p_student_id and a.is_correct
      ) as ever_correct
    from public.lesson_items li
  )
  select
    cu.id,
    cu.title_fil,
    count(isr.lesson_item_id)::integer as total_items,
    count(*) filter (where isr.attempted)::integer as attempted_count,
    count(*) filter (where isr.ever_correct)::integer as correct_count,
    case
      when count(*) filter (where isr.attempted) = 0 then null
      else round(
        count(*) filter (where isr.ever_correct)::numeric
          / count(*) filter (where isr.attempted),
        4
      )
    end as accuracy
  from public.curriculum_units cu
  left join item_stats isr on isr.u_id = cu.id
  group by cu.id, cu.title_fil, cu.sort_order
  order by cu.sort_order;
end;
$$;

comment on function public.student_unit_mastery(uuid) is
  'Per-unit progress summary for one student: item counts, ever-attempted / ever-correct counts, and accuracy. Callable by the student, a linked parent, or the student''s class teacher.';

-- ---------------------------------------------------------------------------
-- Grants: clients call these as `authenticated`, never with elevated table
-- privileges directly.
-- ---------------------------------------------------------------------------
grant execute on function public.record_learn_completion(uuid) to authenticated;
grant execute on function public.record_assessment_attempt(uuid, text, boolean) to authenticated;
grant execute on function public.redeem_reward(uuid) to authenticated;
grant execute on function public.student_unit_mastery(uuid) to authenticated;
