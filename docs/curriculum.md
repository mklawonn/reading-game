# Curriculum — the five-stage spine

The game recapitulates the historical development of writing, following Gleitman & Rozin (1973),
*Teaching Reading by Use of a Syllabary* ([`research/`](research/)). Each stage isolates one cognitive
step so the child never faces two hard ideas at once.

## The core idea (why this order)

Reading English requires two insights that ordinary phonics introduces **simultaneously**:

1. **Phoneticization** — writing tracks the *sound stream*, not meaning directly.
2. **The phoneme** — alphabet letters map to abstract phonemes, which are hard to say in isolation
   (you cannot pronounce "b" without a vowel) and hard to blend.

Syllables are concrete, pronounceable, and easy to blend (`o` + `pen` → `open`). So we teach
phoneticization with **syllables first**, and only later reveal the phoneme and the alphabet as an
efficient mnemonic for the unwieldy set of syllables.

## Stages

### Stage 0 — Listen & blend (pre-print)
- **Skill:** hear syllables spoken with gaps and recognize the word (`win… dow` → *window*).
- **No print yet** — pure auditory blending, building the intuition that words are sequences of
  syllable-sounds.
- **Paper basis:** the "speak slowly" game.

### Stage 1 — Pictographs
- **Skill:** read picturable monosyllables shown as pictures: `CAN` (a tin can), `BEE`, `SUN`, `PEN`,
  `PUP`, `SILL`, window, `SEE`, plus expansion pictographs (`HAND`, `MAN`, …). Arrange pictographs in a
  row and "read" the sentence.
- **Rebus insight:** the *can* picture also spells the **word** *can* (auxiliary verb) — meaning gives
  way to **sound**. This is the first taste of phoneticization.
- **Paper basis:** pictorial symbols + the rebus principle.

### Stage 2 — Syllables (captured via symbols)
- **Skill:** non-picturable syllables get **designed symbols / letter-arrays** (`AND`, `FOR`, `ER`,
  `IN`, `TO`, `IS`). Then **blend by overlapping cards** to build new words:
  `O`+`PEN` → *open*, `SILL`+`E` → *silly*, `WIND`+`O`+`SILL` → *windowsill*, `PEN`+`SILL` → *pencil*.
- **The productive moment:** the child reads/builds words **never seen before** from known syllables —
  proof that the orthography tracks sound.
- **Paper basis:** the syllabary + rebus blending engine.

### Stage 3 — Phonemes (captured via symbols)
- **Skill:** begin to crack syllables into phonemes, using the paper's transition tactics:
  - **Continuant consonants first** (`s, f, m, z`) — pronounceable in isolation, avoiding the "uh"
    artifact of stops (`p, d, k`).
  - **Plural -s card:** "to say more than one, add the `s` card" → `pup` + `s` → *pups*.
  - **Alternative segmentation:** the same word split two ways (`CAN`·`DY` vs `CAND`·`Y`) reveals the
    shared letter — the phoneme "atom" inside the syllable "molecule."
  - **Rhyme & alliteration families:** `and / sand / hand` highlight a shared sound.
- **Paper basis:** "Back to the phoneme."

### Stage 4 — Letters / alphabet
- **Skill:** letters are revealed as an **efficient mnemonic** for the (too-many) syllables. Map known
  syllables/phonemes onto conventional spelling; introduce **rule-governed spelling variants**
  (consonant doubling: *sunny, butter, sitting*). Read simplified all-English text.
- **Paper basis:** transition to alphabetic notation; ordering exceptions by frequency.

## Cross-cutting pillar — tap-to-hear everywhere

Every symbol (pictograph, glyph, letter) and every word carries an audio asset; tapping plays it. This
scaffolding is what makes initially-arbitrary symbols learnable and is a hard requirement in **every**
game and screen. It is encoded as the `audio_ref` field on every Content Bank entry.

## Profiles & progression

A **parent/guardian account** owns one or more **child profiles** (no child PII; see
[`privacy-compliance.md`](privacy-compliance.md)). Each profile carries the progression state below.

### A stage is a center of gravity, not a switch

"Mostly pictographs → mostly syllables" is a **ratio** the game shifts gradually, not a flip. Each
session is composed from a **mix** weighted by the child's progress (≈ 90/10 → 60/40 → 40/60 → 20/80
pictograph/syllable); "moved to mostly syllables" just means that mix crossed 50%. This avoids cliffs
and keeps earlier material resurfacing in spaced review.

### Mastery is measured from gameplay

The games already produce correct/incorrect signals, so **they are the assessment** — no separate test.
Per Content Bank entry we keep a light mastery state (a **Leitner/SRS box**: promote on correct, demote
on wrong; "mastered" = a high box reached with a correct recall *after a spacing gap*), plus a few
tracked **skills** (e.g. `blend`, later `segment`).

### Readiness gate — example: pictographs → syllables

Advance the mix when **all** hold:
- **Coverage** — mastered ≳ 75% of the Stage's *core* items, **durably** (recalled across ≥ 2 sessions,
  not one lucky run).
- **Bridge skill (the real signal)** — the child blends two known pieces into a **novel** word never
  explicitly taught (a fresh Build-a-Word, or reads a new blend in Find-the-Character). This is the
  paper's *productive blending* — evidence the syllable idea clicked, and it outranks raw item count.
- **Stability** — recent accuracy isn't sliding (last ~3 sessions ≥ ~80%).

Two guards against false mastery: require it shown **across modalities** (by ear, by sight, by
construction — not one game) and **across time** (spacing); plus a **working-set cap** (~5–7 unmastered
items in flight) so new material enters just above current mastery (i+1), not in a flood.

The same machinery generalizes: **syllable → phoneme** uses *segmenting a known syllable* (CAN·DY vs
CAND·Y) as its bridge skill; **phoneme → letter** follows.

### Where it lives & what's tunable

Per-child mastery/skill state persists in **Firestore**
(`/parents/{uid}/children/{id}/mastery/{entryId}` + a profile-level mix vector). Every threshold
(coverage %, blend accuracy, ramp rate, working-set cap, accuracy floor) lives in **Remote Config** so
it can be tuned per cohort / A-B without a release. One product dial — **conservative** (be sure before
advancing) vs **eager** (advance on early evidence) — plus the coverage % sets the overall pace.

Implementation: start with the Leitner-SRS + bridge-gate model (simple, interpretable, tunable);
optionally upgrade to Bayesian Knowledge Tracing later.

### Gamification sits on top — and stays decoupled

Levels, XP, streaks, and achievements are a **separate layer** that consumes generic **learning events**
(`{itemId, skill, stage, correct, game}`) emitted by the games. It never references specific words or
pictographs: achievements are defined over **aggregates and stages** (items mastered, streak length,
stage %), and stage progress is **derived from the Content Bank's `introduced_stage` metadata**. So the
curriculum can change — add/reorder/retune content — without touching the game mechanics or the
progression engine. See `app/lib/progress/` (the `LearningEvent` seam).

## How stages map to games

| Stage | Primary games (see [`games.md`](games.md)) |
|---|---|
| 0 | Listen & Pick |
| 1 | Find-the-Character, Match/Memory, Story Builder (pictograph render) |
| 2 | Build-a-Word, Find-the-Character, Story Builder (syllabary render) |
| 3 | Rhyme Families, Build-a-Word (phoneme variants) |
| 4 | Free Read, Story Builder (letters render) |
