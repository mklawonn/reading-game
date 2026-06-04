# Content Bank strategy — choosing words & symbols

The **Content Bank** ([`../content/`](../content/)) is the single source of truth for every symbol and
word in the game. This document defines **how we decide what goes in it**.

## Governing principle — usefulness must justify decomposition cost

A word earns its place only when its **value** (frequency *and* story/game utility) outweighs the
**cost** of breaking it cleanly into syllables/phonemes and depicting it. This cuts both ways:

- We **drop** high-frequency words — including Dolch entries — that are decomposition-hostile or
  low-value (e.g. odd spellings, no clean syllable break, nothing to picture).
- We **add** lower-frequency but concrete, easily-depicted, cleanly-decomposable words that pull their
  weight in stories (a vivid picturable noun can be worth more than a colorless function word).

> Frequency lists (Dolch in [`research/SightWord.pdf`](research/), later Fry) are **reference signals,
> not the spine.** `SightWord.pdf` is included for reference only.

## The five signals

Score each candidate; signals **1 + 3 + 4 = value**, signal **2 = cost**.

1. **Importance / frequency** — appears in Dolch/Fry or is obviously core to children's talk. One
   signal, never a mandate.
2. **Syllabic/phonemic decomposability & combinability** *(cost)* — does it split into clean CV/CVC
   syllables that **recombine into many other words**? High combinability is the paper's core
   efficiency lever (a few syllables → many words). Hostile spelling or no clean break is a strong veto.
3. **Picturability** — can it be an instantly-recognizable pictograph? Favor concrete objects in a
   child's world. Picturable syllables carry far less memory burden.
4. **Story/game utility** — does the overall set contain the connectives, pronouns, and verbs needed to
   form sentences and simple narratives (`I, a, and, is, to, see, get, can, for` …)? Some low-glamour
   function words are mandatory for prose even if unpicturable.
5. **Phoneme-transition affordances** — does it set up Stage 3–4? Prefer including some rhyming
   syllables, multi-segmentation words (*candy* → `CAN·DY` / `CAND·Y`), continuant-initial syllables,
   and basic spelling patterns (`ING`, `ALL`).

## Spelling-regularity ordering

Introduce **regular** sound↔spelling correspondences first. Bring in **rule-governed** variants early
and explicitly (consonant doubling before `-y`/`-er`/`-le`/`-ing`: *sunny, butter, little, sitting*).
**Defer truly irregular words** until the general principles are established, then order remaining
exceptions by frequency.

## Tiers of symbol (detail in [`symbol-art-strategy.md`](symbol-art-strategy.md))

- **Pictograph** — picturable syllables (`CAN, BEE, SUN, PEN, PUP, …`).
- **Designed glyph / letter-array** — necessary but unpicturable syllables (`AND, FOR, ER, IN, TO`).
- **Letter** — Stage 3–4 phonemes/letters.

Every tier requires an `audio_ref`. Symbols must be visually **discriminable** from one another (the
paper warns that symbol confusions are a real failure mode).

## How this becomes data

The strategy is operationalized as **fields on each Content Bank entry** (see
[`../content/schema.md`](../content/schema.md)):

- `frequency` (`dolch_tier` / `fry_rank`, optional) — signal 1
- `decomposition_cost` — signal 2
- `picturable` — signal 3
- `utility_score`, `story_tags[]` — signal 4
- `rhyme_group`, `alt_segmentation[]`, `continuant`, `spelling_variants[]` — signal 5
- `inclusion_rationale` — one line recording *why this entry earned its place* (or why a tempting word
  was excluded, in `content/excluded.md` later)

## Versioning

- **v0** (now) — seeded from the paper's Table 1 (22 elements + their blends) to bootstrap the engine.
- **v1** (M1) — the curated Stage-1 set produced by applying this methodology.
- Each version is a validated artifact (`content/validate.mjs` runs in CI).
