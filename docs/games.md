# Games

All games share two invariants: they read content from the **Content Bank**, and **every symbol is
tappable to hear its sound**. Games are rendered in the child's **current-stage orthography**
(pictograph → syllabary → letters), so the same game grows with the learner.

Every game is playable two ways: standalone (its own rounds + next arrow) and as a
**single-round lesson step** (`singleRound` + `focusId` + `onRoundComplete`) inside the
lesson loop — see [`lessons.md`](lessons.md).

## Summary

| Game | Stage(s) | MVP | One-liner |
|---|---|---|---|
| Story Builder | 1–4 | M3 | Co-write a branching story with an LLM, constrained to learned vocabulary |
| Find the Character / Do the Command | 1–2 | M2 | Read a sentence, tap the thing it names |
| Picture to Word | 1–2 | M2 | See a picture + hear its name, pick the **written** word (reverse of Find-the-Character) |
| Symbol Hunt (I-Spy) | 1 | M2 | "Find **all** the cats!" — tap every target in a grid |
| Build-a-Word (blending) | 2 | M2 | Hear a word, blend syllable cards to build it (print revealed on solve) |
| Blend Magic (reveal) | 2 | M2 | Watch two syllable cards slide together and blend aloud, pick the word made |
| Listen & Pick (slow-speak) | 0 | M2 | Hear gapped syllables, choose the picture |
| Sound Match | 1–2 | M2 | Drag each symbol onto the sound it makes |
| Fill the Blank | 1–4 | M2 | Drag the missing symbol into a phrase (renders per stage) |
| Echo Read | 1–4 | M2 | Tap a phrase's tokens left-to-right, hear it read back fluently |
| Story Time | 1–4 | M2 | A whole lesson node: tap along through a multi-line glyph story (`stories.v1.json`) — never quizzed |
| Hidden Glyph | 1 | M2 | I-Spy search scene: find the 2 hidden copies of the named word's picture among scattered, rotated glyphs |
| Feed the Guide | 1 | M2 | "Fern wants the hat!" — give the hungry guide what it asks for (tap or drag) |
| Build a Sentence | 1–4 | M2 | Hear a sentence, arrange glyph cards to build it (pictograph rows early, real phrases later) |
| Sound Families | 3 | M2 | Match by rhyme or shared first sound (teaches stops by contrast) |
| Free Read | 4 | later | Read leveled stories assembled from the bank |

## Story Builder (signature game) — M3

- The child picks a **"story starter"** (e.g. a character + setting + goal assembled from picturable
  vocabulary).
- An LLM (**Claude**, via the Cloud Functions proxy) generates the next line(s) **using only the
  child's learned symbols/words**.
- Output is rendered in the current-stage orthography with **tap-to-hear** on every symbol; the child
  makes **choices** that branch the story.
- **Guardrails (hard):** server-side **vocabulary whitelist**, **safety filter**, age-appropriate
  system prompt, and **output validation** — nothing out-of-vocabulary or unsafe can reach the screen.
  See [`architecture.md`](architecture.md).
- **Why it matters:** turns decoding practice into authorship; the constraint to learned vocabulary is
  also a natural spaced-review engine.

## Find the Character / Do the Command — M2

- Show a sentence or command in the current orthography; the child **taps the matching pictograph** (or
  carries out a short command by selecting objects in order).
- Directly the paper's **Table 2** comprehension test ("GET A CANDY", "GET A PEN BEFORE A CANDY").
- **Auto-generatable** from the Content Bank, and doubles as a low-stakes **assessment** feeding the
  mastery model.

## Build-a-Word (blending) — M2

- Present a target (heard and/or pictured); the child **drags/overlaps syllable cards** to construct it
  (`O`+`PEN` → *open*).
- The core **syllabary mechanic**; teaches productive blending and that orthography tracks sound.
- Progresses to phoneme variants in Stage 3 (the `-s` card; `CAN·DY` vs `CAND·Y`).

## Listen & Pick (slow-speak) — M2 (Stage 0)

- Play syllables with gaps; the child picks the matching **picture**. Pure auditory blending, no print.

## Sound Match — M2

- The child **drags each symbol** (pictograph/glyph) **onto the sound it makes**; tapping a sound chip
  plays it (TTS for now). Directly exercises the symbol→sound link, and "right symbol → right sound" is
  a clean per-item progress signal feeding the mastery model.
- Selection is **mastery-driven** — the round's focus item comes from the `ItemSampler`.
- **Stage-4 sub-phase (data ready):** the grapheme→phoneme decoding map now lives on each picturable
  element (`graphemes`, e.g. `rain` → r·ai·n = /ɹ·eɪ·n/; `x`→/ks/), validated by `validate.mjs`. The
  word-context matcher (drag a letter-group to its phoneme, multi-letter graphemes as one unit) is
  unblocked **except for isolated phoneme audio** — TTS can't cleanly voice a bare /ʃ/, so this game
  waits on real phoneme clips (same dependency as the broader audio pipeline).

## Fill the Blank — M2

- A short phrase is shown with one token missing; the child **drags the right symbol into the slot**.
  Tap any token to hear it.
- Phrases live in `content/phrases.v1.json` as **sequences of Content Bank element ids** — so one
  authored phrase renders in whatever orthography the child's stage calls for (pictographs early,
  letters later). This is the engine for the owner's **"repeat stories/phrases across levels"**: the
  same sentence resurfaces, re-rendered, as the learner advances.
- The blank is **mastery-driven** (the `ItemSampler` chooses which item to drill), and each answer
  emits a `read` `LearningEvent`.

## Sound Families — M2 (Stage 3)

- Minimal-pair contrast: a target word is shown/heard, and the child taps the one option that shares
  its **rhyme** (cat → hat) or its **onset** (key → can). Modes alternate per round.
- **This is how we handle stops.** A stop (p, b, t, d, k, ɡ) can't be voiced in isolation, so onset
  mode teaches it *by contrast* — key·can·cat share a beginning the child hears, never a bare /k/. The
  "hear the sound" button uses the stop/continuant-aware `speakPhoneme` (keyword anchor for stops,
  held sound for continuants). See `docs/curriculum.md` → "the sound layer".
- Data-driven by `rhyme_group` and the grapheme map's first phoneme (`onsetPhoneme`); selection is
  mastery-weighted via the `ItemSampler`.

## Free Read — later (Stage 4)

- Leveled stories assembled from the bank in (mostly) conventional spelling, with comprehension checks —
  the bridge to ordinary reading.

## Game ideas parked for later

- **Build-a-Sentence:** arrange word/symbol cards into a valid *whole* sentence (the productive
  counterpart to Fill-the-Blank, which fills a single slot).
- **Symbol Hunt / I-Spy:** find the symbol whose sound the narrator says.
- **Story Theater:** the child's finished Story Builder tale is read back with simple animation.
