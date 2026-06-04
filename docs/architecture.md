# Architecture

## Overview

```
┌─────────────────────────────┐        ┌──────────────────────────────────────────┐
│        Flutter app          │        │                 Firebase                    │
│  (iOS + Android, responsive)│        │                                            │
│                             │        │  Auth (parent)   Firestore   Storage/CDN   │
│  • Content Bank (bundled)   │◀──────▶│  Remote Config   Analytics   Crashlytics   │
│  • tap-to-hear audio        │  HTTPS │  App Check                                  │
│  • games (stages 0–4)       │        │                                            │
│  • progress sync            │        │  Cloud Functions ── Story Builder proxy ──▶ │ Claude API
└─────────────────────────────┘        └──────────────────────────────────────────┘
```

## Client (Flutter)

- **Single codebase** for iOS + Android; **responsive** for phone and tablet (layout adapts; large
  touch targets for early learners).
- **Custom rendering** for pictograph "cards" and the **overlap = blend** animation (CustomPainter /
  implicit animations).
- **Audio layer** (`audioplayers` or `just_audio`) — the tap-to-hear primitive used everywhere.
- **Content** is **bundled** with the app for offline play; **progress** syncs to Firestore when online.
- Suggested structure (M0 seed in [`../app/lib`](../app/lib)):
  `models/` (Content Bank types), `services/` (content loader, audio, auth), `features/<game>/`.

## Firebase services

| Service | Use |
|---|---|
| **Auth** | Parent/guardian accounts only (email + Google + **Sign in with Apple**, required for App Store). No child accounts. |
| **Firestore** | Parents, child profiles, per-skill mastery/progress. |
| **Storage / CDN** | Art & audio asset delivery and updates (assets may also ship bundled). |
| **Cloud Functions** | **Story Builder** LLM proxy; telemetry aggregation. |
| **Remote Config** | Stage-gating thresholds, curriculum A/B, feature flags. |
| **Analytics + Crashlytics** | Learning analytics (privacy-safe) + stability. |
| **App Check** | Attest that backend calls come from our genuine app. |

## Data model (Firestore, initial sketch)

```
/parents/{uid}                      # parent account doc (no marketing profile)
/parents/{uid}/children/{childId}   # child profile: displayName (non-PII nickname), avatar, stage
/parents/{uid}/children/{childId}/mastery/{entryId}   # per-symbol/skill mastery, lastSeen, streak
/content/{version}                  # optional server mirror of Content Bank metadata (read-only)
```

**Security rules (skeleton in [`../backend/firestore.rules`](../backend/firestore.rules)):** a parent
can read/write only documents under their own `uid`; `/content` is read-only to clients; everything
else denied by default.

## Story Builder LLM integration

A **callable Cloud Function** (`backend/functions/src/storyBuilder.ts`) is the only path to the LLM, so
the API key never ships in the app and all output passes server-side guards.

Request → response flow:
1. **AuthN/AuthZ + App Check** — reject unauthenticated or unattested callers.
2. **Inputs:** the chosen story-starter and the child's **learned-vocabulary list** (entry ids).
3. **Prompt:** a **prompt-cached, stable system prompt** (per the project's `claude-api` guidance) with
   the rules, age-appropriateness, and **structured-JSON** contract; the **per-child vocabulary
   whitelist** + stage + story-starter ride in the **user message** to keep the cache warm.
4. **Model:** Claude — default `claude-opus-4-8`; set `STORY_MODEL=claude-sonnet-4-6` to trade
   capability for lower cost/latency.
5. **Validation:** parse JSON; **reject any token outside the whitelist**; run a safety filter; on
   failure, retry once then fall back to a safe canned line.
6. **Response:** validated, vocabulary-safe story segment + choice options.

For M0 the function is a **stub**: if `ANTHROPIC_API_KEY` is unset it returns a canned,
vocabulary-constrained segment so the flow is testable without a key.

## Environments

- **Local:** Firebase **Emulator Suite** (Auth, Firestore, Functions) + `flutter run`.
- **Dev / Prod:** separate Firebase projects (`.firebaserc` aliases). Secrets via
  `firebase functions:secrets:set` — never in the repo.

## CI

`.github/workflows/ci.yml`: validate the Content Bank, `flutter analyze` + `flutter test`, and
`tsc --noEmit` for functions.
