# Supabase backend — Gamified Filipino Learning

Backend for the Flutter student app, the Flutter-web teacher CMS, and the
parent progress/rewards dashboard. Postgres + Auth + Storage + Edge
Functions, all via Supabase.

## 1. Create a Supabase project

1. Sign up / log in at [supabase.com](https://supabase.com) and create a new project.
2. Install the CLI if you don't have it: `npm install -g supabase` (or `brew install supabase/tap/supabase`).
3. From the repo root: `supabase login`, then `supabase link --project-ref <your-project-ref>` (find the ref in the project's Settings → General page).

## 2. Apply the schema + seed data

Option A — CLI (recommended):

```bash
cd supabase
supabase db push        # applies migrations/0001_init.sql, 0002_rls.sql, 0003_functions.sql in order
```

Then load the starter curriculum content. `db push` does not run `seed.sql`
automatically against a *remote* project (it's used by `supabase db reset`
for local dev), so for a remote project either:

```bash
supabase db execute --file seed.sql
```

or paste `seed.sql`'s contents into the Supabase Dashboard's SQL Editor and run it.

Option B — SQL Editor only (no CLI): open the Dashboard's SQL Editor and run,
in order, `migrations/0001_init.sql`, `migrations/0002_rls.sql`,
`migrations/0003_functions.sql`, then `seed.sql`.

For local development: `supabase start`, then `supabase db reset` applies
all migrations *and* `seed.sql` against your local Postgres in one shot.

## 3. Set the Gemini API key and deploy the edge function

```bash
supabase secrets set GEMINI_API_KEY=your-gemini-api-key-here
supabase functions deploy ai-helper
```

That deploys with JWT verification ON (the default) — the function only
runs for requests carrying a valid Supabase user session
(`Authorization: Bearer <jwt>`), which is what the Flutter web CMS sends
automatically via `supabase.functions.invoke(...)`. Only pass
`--no-verify-jwt` if you specifically need the function reachable without a
Supabase session (not the case for this CMS-only helper) — see the comment
at the top of `functions/ai-helper/index.ts` for details.

Call it from Flutter like:

```dart
final res = await Supabase.instance.client.functions.invoke(
  'ai-helper',
  body: {
    'mode': 'suggest_lesson_items',
    'unit_context': 'Mga Hugis (Shapes)',
    'prompt': 'Suggest 5 more shape vocabulary items for kindergarten.',
  },
);
// res.data == { "text": "..." } on success.
// A non-2xx response throws a FunctionException whose message/details
// carry the { "error": "..." } body.
```

## 4. Schema overview (ER diagram in words)

```
auth.users (Supabase-managed)
  └─ profiles (1:1)                 role: student | teacher | parent
       └─ class_students (student's class membership; N:1 → classes)
  └─ parent_children                parent_id ↔ student_id (M:N link table)

classes
  ├─ teacher_id → auth.users        (a teacher owns a class)
  └─ class_students                 (a class has many enrolled students)

curriculum_units                    e.g. Alpabetong Filipino, Mga Numero...
  └─ lessons (N:1 → curriculum_units)
       └─ lesson_items (N:1 → lessons; unit_id denormalized + trigger-synced)

lesson_items
  ├─ learn_completions              (student_id, lesson_item_id) — "learn" mode done
  └─ assessment_attempts            (student_id, lesson_item_id) — every spoken attempt

points_transactions                 append-only ledger: student_id, source_type
                                     (learn | assessment | reward_redeem), source_id,
                                     delta, note, created_at
  → student_points_balance (view)   sum(delta) per student_id

rewards                             parent_id, student_id (per-child), point_cost, active
  └─ reward_redemptions             student_id, reward_id, status, points_spent,
                                     requested_at, decided_at, decided_by
```

Key relationships:
- A **student**'s profile role determines what they can do; their
  `class_students` row (if any) says which class/teacher they belong to,
  and `parent_children` rows say which parent(s) can see their data.
- A **teacher** owns `classes` and can read progress data (learn
  completions, assessment attempts, points transactions) for any student in
  a class they own, via `class_students` → `classes.teacher_id`.
- A **parent** is linked to one or more students via `parent_children` and
  can read progress/points/redemptions for those students, plus manage
  `rewards` and approve/reject `reward_redemptions` for them.
- **Points** only ever move through `points_transactions`, and that table
  is never written directly by a client — only by the SECURITY DEFINER
  functions in `0003_functions.sql`. This is the app's core anti-cheat
  boundary: a compromised or modified client cannot grant itself points.

## 5. Design decisions made beyond the original brief

These weren't fully pinned down by the spec, so here's what was chosen and why:

- **Class membership**: `class_students` join table (`class_id`,
  `student_id`) rather than a column on `profiles`, with a `UNIQUE(student_id)`
  constraint so a student still belongs to at most one class at a time in
  practice (keeps the "simple class model" the brief asked for, while
  matching the table/column names the Flutter client expects).
- **`lesson_items.unit_id`**: kept as a denormalized column alongside the
  real hierarchy edge `lesson_id`, auto-populated by a trigger
  (`sync_lesson_item_unit_id`) from the parent lesson so it can never drift.
  This satisfies both "curriculum_units → lessons → lesson_items" as the
  structural hierarchy and the explicit ask for a `unit_id` field on
  `lesson_items`.
- **Points values**: learn-mode completion = **2 points** (fixed, once per
  item, idempotent via a unique constraint). Assessment first-correct
  attempt = **base 5 × multiplier 3 = 15 points**. "First-correct-attempt"
  is interpreted as *first ever correct attempt per lesson_item* (not reset
  per login session) — re-answering correctly after already having earned
  points for that item awards 0 again, but the attempt is still logged.
- **Assessment correctness is server-recomputed, not client-trusted**:
  `record_assessment_attempt(p_lesson_item_id, p_transcript, p_is_correct)`
  keeps the `p_is_correct` parameter for API shape, but the function ignores
  it for scoring — it independently normalizes and compares `p_transcript`
  against `lesson_items.filipino_text` and `accepted_variants` to decide
  correctness itself. Otherwise a client could simply pass `true` and farm
  points.
- **Reward redemption flow**: points are **deducted at request time**
  (`redeem_reward` inserts a `pending` redemption and a matching negative
  ledger row atomically), not at approval time. `reward_redemptions.points_spent`
  freezes the cost so a later edit to `rewards.point_cost` can't corrupt a
  refund. If a parent rejects a request, an `AFTER UPDATE` trigger
  (`refund_rejected_redemption`) automatically inserts a compensating
  positive ledger row. Approving/fulfilling has no further ledger effect
  since the points were already spent. This was chosen over deduct-on-approval
  because it stops a student from firing off many pending requests they
  can't actually afford while waiting on parent approval.
- **Rewards are per-child, not a shared family pool**: `rewards.student_id`
  ties each reward to one specific linked child (enforced by the
  `validate_reward_student_link` trigger, which checks the `(parent_id,
  student_id)` pair exists in `parent_children`), rather than one reward
  catalog shared across all of a parent's kids.
- **`parent_children` has no client-facing INSERT policy**: linking a
  parent account to a student account is treated as a trust boundary that
  should go through a verified/admin process (service-role key), not
  something any signed-in parent can self-assert for an arbitrary student
  id. For this MVP, rows are created by an administrator; RLS grants SELECT
  only. A verified invite-code flow can add self-service linking later
  without changing this table's shape.
- **`student_unit_mastery(p_student_id)` RPC**: added to back the
  teacher/parent progress dashboards. Per curriculum unit, it reports total
  items, how many the student has *ever* attempted, how many they have
  *ever* gotten correct at least once (not "most recent attempt only" — a
  student who eventually nails an item after a few tries counts as having
  mastered it), and `accuracy = correct/attempted` (`NULL`, not `0`, when
  nothing has been attempted yet, so an unstarted unit doesn't look like a
  failing one). Access is restricted inside the function to the student
  themself, a linked parent, or the student's class teacher — the same
  boundary as the RLS policies elsewhere.
- **`student_points_balance` view uses `security_invoker = true`**: without
  it, a view created by the migration role (which has `BYPASSRLS`) would
  silently expose every student's balance to any authenticated caller,
  since a plain view's row-security evaluation defaults to the view
  *owner's* privileges rather than the querying user's. This is a common
  Postgres/Supabase gotcha worth flagging explicitly.
- **`handle_new_user()` trigger** on `auth.users` auto-creates a `profiles`
  row on sign-up, reading `role`/`full_name` out of `raw_user_meta_data`
  (defaults to `role = 'student'` if not supplied). A narrow
  `profiles_insert_self` RLS policy exists as a fallback for direct
  client-side upserts of a user's own profile.

## 6. Files in this directory

- `migrations/0001_init.sql` — extensions, enums, all tables, indexes, `updated_at` triggers, `student_points_balance` view.
- `migrations/0002_rls.sql` — RLS enablement + every policy (the app's main security boundary — read the comments here first).
- `migrations/0003_functions.sql` — SECURITY DEFINER functions (`record_learn_completion`, `record_assessment_attempt`, `redeem_reward`, `student_unit_mastery`) plus the reward-rejection refund trigger.
- `seed.sql` — MATATAG-aligned starter content for the 4 launch units.
- `functions/ai-helper/index.ts` — Gemini-backed AI helper edge function for the teacher CMS.
- `config.toml` — minimal local-dev CLI config.
