# Symbol & art strategy — which symbols to draw, and how

We must draw a set of symbols and pair each with sound. This document defines **which** symbols get
drawn, in **what visual language**, and the **production pipeline**.

## Three tiers

### 1. Pictograph tier (the heart of Stage 1)
Instantly-recognizable line-art for **picturable syllables**.

**Selection rule:** a syllable earns a pictograph **iff** it maps to a concrete, unambiguous object
whose **name *is* that syllable**, favoring objects in a young child's world.

- Good: `CAN` (tin can), `BEE`, `SUN`, `PEN`, `PUP`, `HAND`, `KEY`, `EYE`, window (`WIND`).
- Rejected: objects whose name is ambiguous, abstract, or culturally narrow, or whose obvious drawing
  could be read as several different words.

### 2. Designed-glyph / letter-array tier
For **necessary but unpicturable** syllables (`AND`, `FOR`, `ER`, `IN`, `TO`, function words). Two
options, chosen per-symbol:
- **Letter-array** (as in the paper): render the syllable as its letters in the card style (`ER`, `AND`).
- **Invented glyph:** a distinctive mark when letters would be confusable or before letters are taught.

### 3. Letter / phoneme tier (Stages 3–4)
Transitional glyphs that resolve into **conventional letters**.

## Visual language (style guide — to be finalized in M1)

- **High contrast, bold line-art**, minimal detail, friendly rounded forms.
- **Consistent stroke weight & palette** across all symbols.
- **Card framing:** every symbol sits on a "card" so the **overlap = blend** mechanic reads clearly
  (overlapping two cards = one word). Cards have a consistent aspect ratio and a syllable-divider motif.
- **Discriminability is a hard requirement.** No two symbols should be confusable at thumbnail size or
  for color-blind users. Maintain a confusion-check matrix as the set grows.
- **Accessibility:** large touch targets, no meaning conveyed by color alone, legible at phone size.

## Audio pairing (mandatory)

Every symbol — every tier — has an `audio_ref`. Each entry typically needs:
- the **syllable sound** in isolation (for blending), and
- the **word pronunciation(s)** for any word(s) it spells.

Recording plan (M1): start with **TTS placeholders**, replace with **professional child-directed
voiceover**; keep clips short, normalized in loudness, and named by Content Bank `id`.

## Production pipeline

```
Content Bank entry  →  inventory (which symbols are needed, by stage)
                    →  style guide / spec (M1)
                    →  PLACEHOLDER glyphs + TTS audio   ← unblocks engineering now
                    →  final art (commissioned or AI-assisted, human-refined)
                    →  final audio (professional VO)
                    →  QA: discriminability + recognizability testing with kids
```

## Asset conventions

- **Filenames keyed to Content Bank `id`:** `assets/images/pictographs/<id>.png`,
  `assets/audio/<id>.<syllable|word>.mp3`.
- **Formats:** prefer **SVG** masters for line-art (crisp at any density), exported to PNG/WebP as
  needed by the renderer; **mp3/m4a** for audio.
- **Versioning:** when binary assets grow, migrate `app/assets/{images,audio}` to **Git LFS**.

## M0 placeholders

For the runnable skeleton we ship simple **generated placeholder glyphs** (a framed card with the
syllable text) and TTS or silent-tone audio, purely to prove the content→UI→audio loop. None of this
art is final.
