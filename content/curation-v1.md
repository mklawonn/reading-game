# Content Bank v1 — Stage-1 vocabulary curation

This is the curated **Stage-1** vocabulary: **53 elements → 76 words** (incl. plural `-s` and `-ing`). It expands the v0 seed
(Gleitman & Rozin's 22-element Table 1) into a set that can actually tell simple stories and feed all
the games. The data is `content/content_bank.v1.json`; this doc is the **reviewable selection and the
why**. Methodology: [`docs/content-bank-strategy.md`](../docs/content-bank-strategy.md)
(usefulness must justify decomposition cost).

## The shape of the set

| Tier | Count | What |
|---|---|---|
| **Pictographs** (picturable anchors) | 27 | The fun, low-memory-burden core — each is a word *and* a reusable syllable, and most head a rhyme family. This is the "many depictable by instantly-recognizable pictographs" goal. |
| **Function / verb / adjective glyphs** | 16 | The sentence connective tissue (letter-arrays): articles, prepositions, pronouns, a few high-frequency verbs/adjectives. Higher memory cost, kept lean. |
| **Suffix & connective glyphs** | 10 | `o` (open/window), `e` (-y), `er`, plural `-s`, `-ing`, `day`, plus blend-only syllables `for/get/it/sill`. |
| **→ generates** | **76 words** | single words + blends + plural/`-ing` forms. |

**Design lever:** few elements, many words. Picturable anchors were chosen to *recombine* (pen → open,
penny, pencil) and to *head rhyme families* (so the same 27 pictures power Build-a-Word, Listen & Pick,
Find-the-Character, and a future Rhyme game).

## Pictograph anchors (the 27 picturable symbols to draw)

Grouped by the rhyme family each anchors:

| Family | Pictographs | Also in family (glyphs) |
|---|---|---|
| **-at** | cat 🐱, hat 🎩 | |
| **-en** | pen 🖊️, hen 🐔 | |
| **-og** | dog 🐕 | |
| **-ig** | pig 🐷 | big |
| **-ug** | bug 🐛 | |
| **-ed** | bed 🛏️ | red |
| **-un** | sun ☀️ | run |
| **-ox** | fox 🦊, box 📦 | |
| **-ot** | pot 🍲 | hot |
| **-et** | net 🥅 | get |
| **-an** | can 🥫, man 🧍 | |
| **-up** | pup 🐶 | up |
| **-ee** | bee 🐝, key 🔑 | see |
| **-all** | ball ⚽ | |
| **-ing** | ring 💍 | |
| **-ow** | snow ❄️, cow 🐄 | go |
| **-ain** | rain 🌧️ | |
| **-and** | hand ✋ | and |
| **-oy** | boy 👦 | |
| **-ind** | wind 🪟 (window) | |
| — | i 👁️ (eye = "I") | |

`pen`, `sun`, `pup`, `wind`, `bee`, `can` are the **high-combinability** anchors (each feeds several
blends). 14 rhyme families have ≥2 members — the raw material for Stage-3 phoneme awareness.

## Function / verb / adjective glyphs (the lean connective core)

`a · the · is · in · on · to · up · and · go · see · my · run · sit · big · red · hot`

These are unpicturable but mandatory for prose. Most also double as **rhyme-family members**
(run/-un, big/-ig, red/-ed, hot/-ot, sit/-it, up/-up) so they pull double duty. `the` is kept as a
whole sight-syllable (its `th` is irregular and deferred).

## Suffix & connective glyphs

`o` (open, window) · `e` (the -y in sunny/puppy) · `er` (sunnier; Stage-3) · `day` (sunday, today) ·
plus blend-only syllables `for` (before, forget) · `get` · `it` (puppet) · `sill` (silly, pencil,
windowsill).

## The words it generates

- **Single (46):** the 27 pictograph words (incl. "I") + `a the is in on to up and go see my run sit big
  red hot for get it day`.
- **Blends (21):** `open` (o+pen), `penny` (pen+e), `sunny` (sun+e), `puppy` (pup+e), `rainy`, `snowy`,
  `handy`, `silly` (sill+e), `windy`, `window` (wind+o), `into` (in+to), `today` (to+day), `sunday`,
  `cowboy` (cow+boy), `snowman` (snow+man), `forget` (for+get), `sunnier` (sun+e+er), and the
  **held-out test blends** `before` (bee+for), `pencil` (pen+sill), `puppet` (pup+it), `windowsill`
  (wind+o+sill) — reserved (`is_test_blend`) to assess productive blending, per the paper.

## Stories this set can already tell (vocabulary-true samples)

> I see a big red hen. · The cat is on my bed. · Can a fox get in the box? · My puppy can run to the
> sun. · It is a sunny day — I see a bee. · The cow and the boy go to the windowsill.

## Key decisions & flags (for your review)

- **Rebus picture-words kept (flagged in data):** `i` = an eye 👁️ (eye→I), `bee` supplies the "be" in
  *before*, `o`/`wind` build *open*/*window*. These are pedagogically endorsed and make pictures do
  double duty. Easy to drop if you'd rather stay strictly phonetic.
- **Spelling-doubling taught early:** `penny/sunny/puppy/sunnier` carry `spelling_variants` (penn-,
  sunn-, pupp-) so the doubling-before-`-y` rule surfaces in context.
- **Now included (Stage-3 bridge):** plural `-s` (cats, pups — the paper's own pup+s example) and
  `-ing` (going, raining, running with runn- doubling). Marked `introduced_stage: 3`.
- **Still deferred** (for later stages): the alphabet, the numeral-rebus `4=for`, `candy`/`d` (kept out
  to avoid the cheaty `d`=dee), and genuinely irregular words.
- **Frequency is one signal, not the spine:** Dolch tiers are tagged where they apply, but picturable
  nouns (bug, fox, key…) and combinable anchors earn their place on utility, not frequency.

## Suggested first-weeks core (if you want to sequence)

A tight starter subset that still tells stories and blends: **cat, dog, sun, pen, pup, bee, can, hat,
big, red, the, a, I, is, can, see, on, and** → plus blends `open, puppy, sunny`. The rest layers in by
rhyme family.

## What's next (not in this PR)

1. **Wire v1 into the app** (bundle `content_bank.v1.json`, bump the loader) and **expand the games'
   emoji map** to the 27 pictographs (or move to real art).
2. **Art & audio:** produce the 27 pictographs + record syllable/word audio (the 171 validator
   warnings are exactly this asset gap).
3. **Toward 60 (paper's revised target):** obvious next anchors — `boxer`-style `-er` words, `monkey`/
   `money` (mon+), `top/hop` (-op), plural `-s`, a few more verbs.
