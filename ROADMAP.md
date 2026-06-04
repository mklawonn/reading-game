# Reading Game — Roadmap

## Vision

Teach pre-readers to read English by recapitulating the historical development of writing —
**pictograph → rebus → syllabary → alphabet** — following Gleitman & Rozin (1973). A child builds a
profile and advances through five stages, playing games that always let them **tap a symbol to hear
its sound**. Stories are co-created with an LLM from "story starters," constrained to the child's
learned vocabulary.

Why this approach: learning to read English confounds two hard cognitive tasks — (1) realizing that
writing tracks **sound**, not meaning ("phoneticization"), and (2) grasping the abstract **phoneme**.
Syllables are concrete, pronounceable, and blendable, so teaching them first lets a child master
phoneticization *before* facing the phoneme. See [`docs/curriculum.md`](docs/curriculum.md).

## Product principles

1. **Sound is always one tap away.** Every symbol/word has audio; tapping plays it. This removes the
   burden of memorizing initially-arbitrary symbols.
2. **A small, hard-working vocabulary.** Words are chosen by a usefulness-vs-decomposition-cost
   judgment, not by copying a frequency list. See [`docs/content-bank-strategy.md`](docs/content-bank-strategy.md).
3. **One source of truth.** All content lives in the versioned **Content Bank**; every game reads from
   it ([`content/`](content/)).
4. **Play, not drill.** Skills are practiced inside games (stories, find-the-character, blending).
5. **Safe for kids by construction.** COPPA/GDPR-K from day one; LLM output is vocabulary-whitelisted
   and safety-filtered server-side. See [`docs/privacy-compliance.md`](docs/privacy-compliance.md).

## Milestones

### M0 — Foundations  ✅ (this task)
- **Goal:** stand up the project so all later work has a home.
- **Deliverables:** this roadmap + design docs; git repo & conventions; Firebase scaffold (config,
  rules, Functions Claude-proxy stub); **Content Bank v0** seeded from the paper; a **runnable Flutter
  skeleton** demonstrating tap-to-hear; toolchain chosen (Flutter, Firebase, Claude).
- **Exit:** `flutter run` shows tappable pictograph cards that play sound; content validator passes;
  functions typecheck; initial commit on `main`.

### M1 — Content & curriculum
- **Goal:** finalize the Stage-1 inventory and the asset pipeline.
- **Deliverables:** Stage-1 symbol/word set chosen via value-vs-cost scoring (prune hard/low-value
  words, add easy depictable ones); **art style guide**; placeholder→final asset plan; **audio plan**
  (VO vs TTS); **Content Bank v1**.
- **Exit:** every Stage-1 entry has placeholder art + audio and a written inclusion rationale.

### M2 — Core engine + first games
- **Goal:** first real, playable learning loop.
- **Deliverables:** parent auth + child profiles; content loader & progression model; **Build-a-Word**
  (blending), **Find-the-Character** (paper's Table 2), **Listen & Pick** (Stage 0) playable for
  Stages 0–2; mastery tracking persisted to Firestore.
- **Exit:** a child can complete a Stage-1→2 session and see progress saved.

### M3 — Story Builder (LLM)
- **Goal:** the signature creative game.
- **Deliverables:** Cloud Function calling **Claude** with a prompt-cached **stable** system prompt
  (per-child vocabulary whitelist passed in the user turn); output validated against the whitelist +
  safety filter; story UI with "story starter"
  choices, current-stage orthography rendering, tap-to-hear, and branching.
- **Exit:** a child builds a branching story using only learned vocabulary; no out-of-vocabulary or
  unsafe text can reach the screen.

### M4 — Progression depth (phonemes & letters)
- **Goal:** complete the pictograph→letter arc.
- **Deliverables:** mastery model with spaced repetition; stage gating; **Stage 3** (continuant
  consonants, plural -s card, CAN-DY/CAND-Y segmentation, rhyme families) and **Stage 4** (letters as
  syllable mnemonics; rule-governed spelling: sunny/butter/sitting) content + games.
- **Exit:** a learner can move from pictographs to reading simplified all-English text.

### M5 — Polish, compliance & beta
- **Goal:** ship-ready quality.
- **Deliverables:** COPPA/GDPR-K review; Analytics + Crashlytics; App Check; final art & audio;
  accessibility pass; closed beta with a learning-efficacy measurement.
- **Exit:** closed beta running; efficacy signal collected.

## Cross-cutting workstreams (run across milestones)

- **Content Bank** — grows from v0 (paper seed) → v1 (Stage 1) → … ; always validated in CI.
- **Art & audio** — pipeline in [`docs/symbol-art-strategy.md`](docs/symbol-art-strategy.md);
  placeholders unblock engineering; finals land by M5.
- **Compliance & safety** — owned continuously, not a final step.

## Open follow-ups (non-blocking)

- **License:** proprietary placeholder — confirm before any public release.
- **GitHub remote:** not created automatically; will set up a private repo on request.
- **App/brand name & bundle id:** placeholder `com.readinggame.app` until chosen.
