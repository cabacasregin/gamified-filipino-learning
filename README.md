# Gamified Filipino Learning

A gamified Filipino-language learning platform for young learners, aligned
to the Philippine **MATATAG curriculum** (Filipino / Mother Tongue strand),
starting with **Alpabetong Filipino** (alphabet), **Mga Numero** (numbers),
**Mga Hugis** (shapes), and **Mga Kulay** (colors).

One Flutter codebase (`/app`) serves three role-gated experiences:

- **Student** (mobile + web): bite-sized English↔Filipino lessons with
  correct-pronunciation audio, then a spoken-answer assessment ("say
  'isa'" for a card showing 1) that's evaluated on-device and corrected
  when wrong. Points are earned in both modes — a small amount for
  passive learning, a multiplier for a correct spoken assessment answer
  — and can be spent on rewards a parent defines.
- **Teacher** (web): a CMS for curriculum content (units → lessons →
  vocabulary items) with an AI helper (Gemini) for drafting new content
  and sanity-checking translations, plus a class-wide progress dashboard.
- **Parent** (web + mobile): a per-child progress dashboard and reward
  management — define point-cost rewards and approve/reject redemption
  requests.

## Architecture

```
app/         Flutter app (student app, teacher CMS, parent dashboard —
             one codebase, role-based routing). See app/README.md.
supabase/    Postgres schema + RLS policies, seed content (MATATAG-aligned
             starter vocabulary), and a Supabase Edge Function proxying
             Gemini for the CMS AI helper. See supabase/README.md.
```

**Backend:** Supabase (Postgres + Auth + Row Level Security + Edge
Functions). Three roles — student, teacher, parent — enforced at the
database layer, not just in the UI: a parent can only see/manage their
own linked children's data, a teacher only their class's students, and a
student only themself. Points are never written directly by the client;
every point-earning action goes through a `SECURITY DEFINER` Postgres
function that independently re-verifies correctness/eligibility server-side.

**AI helper:** the teacher CMS calls a Supabase Edge Function
(`supabase/functions/ai-helper`) that proxies Google's **Gemini API**
(free tier) server-side, so the API key never reaches the browser. See
`supabase/README.md` for how to get a free key.

**Speech evaluation:** pronunciation is assessed with on-device speech
recognition (no cloud API key required, works offline) rather than a
cloud pronunciation-assessment service — see the design note in
`app/README.md` for the trade-off and how to swap in a cloud provider
later if higher accuracy is needed.

## Getting started

1. **Backend** — follow `supabase/README.md` to create a Supabase
   project, apply the migrations + seed data, set a `GEMINI_API_KEY`
   secret, and deploy the `ai-helper` edge function.
2. **App** — follow `app/README.md` to run the Flutter app (mobile or
   web) pointed at your Supabase project.

## Status

This is a working end-to-end scaffold covering the full request: auth +
role-based apps, MATATAG-aligned starter content across all four units,
learn/assessment/points/rewards flows, teacher CMS with AI helper, and
teacher/parent progress dashboards. It's meant as a strong foundation to
build on, not a polished production app — see the "Next steps" notes in
`app/README.md` and `supabase/README.md` for what to harden before a real
classroom rollout (e.g. broader curriculum content beyond the first four
units, a moderation step before AI-suggested content is published, and
real recorded audio as an option alongside TTS for underrepresented
sounds).
