# filipino_learn (Flutter client)

Single Flutter codebase serving three experiences, gated by the signed-in
user's role:

- **Student** — the gamified learning app (mobile + web).
- **Teacher** — content CMS (curriculum CRUD + AI helper) and a class
  progress dashboard.
- **Parent** — a per-child progress dashboard and reward management
  (set point-cost rewards, approve/reject redemption requests).

See the repo root [`README.md`](../README.md) for the overall architecture
and the `supabase/` backend.

## Running

You need a Supabase project (see `../supabase/README.md` to set one up and
apply the schema/seed data). Then run with the project's URL and anon key
passed via `--dart-define` — they are intentionally not hardcoded anywhere
in source:

```bash
flutter pub get

flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY

# Web:
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY

# Release web build (e.g. for the admin/CMS deployment):
flutter build web \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Without these defines the app shows a "missing configuration" screen
instead of crashing (see `lib/main.dart`).

## Project layout

```
lib/
  core/            Shared architecture: Supabase-backed models, repositories,
                    Riverpod providers, go_router setup, theme, shared widgets,
                    TTS + speech-recognition service wrappers, answer matching.
  features/
    auth/          Login / sign-up (role selection: student/teacher/parent).
    student_home/  Student landing screen (unit picker) + bottom-nav shell.
    learning/      Low-stakes "learn" flow (flashcards + pronunciation audio).
    assessment/    Spoken-answer assessment flow (speech-to-text grading).
    rewards/       Student point wallet + reward catalog; parent reward CRUD
                    and redemption approvals.
    cms/           Teacher curriculum CRUD + AI helper.
    dashboard/     Teacher/parent progress-monitoring dashboards.
```

## Notable design choices

- **Speech evaluation is on-device** (`speech_to_text` package) rather than
  a cloud pronunciation-assessment API, so the app works offline and needs
  no per-request API key/cost. Because most devices lack a dedicated
  Filipino speech model, recognition falls back to the default locale and
  `core/utils/answer_matcher.dart` absorbs the resulting mismatches with
  curated accepted-answer variants plus fuzzy string matching. Swapping in
  a cloud API later (e.g. for higher-accuracy pronunciation scoring) only
  requires changing `SpeechRecognitionService` and `AnswerMatcher`.
- **Pronunciation audio is synthesized with on-device TTS** (`flutter_tts`,
  `fil-PH` locale where available) rather than shipped as recorded audio
  files, so new vocabulary needs no separate audio-recording pipeline.
- **Points are server-authoritative.** The client never writes to
  `points_transactions` directly — it calls Postgres RPCs
  (`record_learn_completion`, `record_assessment_attempt`, `redeem_reward`)
  that independently recompute correctness/eligibility, so a modified
  client can't grant itself points.
