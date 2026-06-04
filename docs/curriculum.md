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

- A **parent/guardian account** owns one or more **child profiles** (no child PII; see
  [`privacy-compliance.md`](privacy-compliance.md)).
- **Mastery** is tracked per Content Bank entry and per skill, with spaced practice.
- **Stage gating:** a child unlocks the next stage when mastery thresholds across the current stage's
  symbols/skills are met. Gating thresholds live in Remote Config so they can be tuned without a release.

## How stages map to games

| Stage | Primary games (see [`games.md`](games.md)) |
|---|---|
| 0 | Listen & Pick |
| 1 | Find-the-Character, Match/Memory, Story Builder (pictograph render) |
| 2 | Build-a-Word, Find-the-Character, Story Builder (syllabary render) |
| 3 | Rhyme Families, Build-a-Word (phoneme variants) |
| 4 | Free Read, Story Builder (letters render) |
