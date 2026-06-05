# Asset pipeline — pictograph art & audio

How Stage-1 assets get produced and dropped in. The Content Bank drives everything;
`content/asset-manifest.json` (regenerate with `node content/gen-asset-manifest.mjs`) is the worklist.

## What v1 needs
- **27 pictograph images** (one per picturable element)
- **129 audio clips** (53 element syllables + 76 word pronunciations)

## How the app consumes assets (drop-in)
- **Images — art-first via `GlyphView`** (`app/lib/content/glyph_view.dart`): for a picturable element
  it shows `assets/images/pictographs/<id>.png` if bundled, **else** the emoji placeholder, **else** the
  syllable as linked letters. So: drop `cat.png` into `app/assets/images/pictographs/`, rebuild, and it
  replaces the 🐱 emoji — no code change.
- **Audio — tap-to-hear**: currently on-device **TTS** speaks the syllable/word. When real clips exist,
  drop `<ref>.mp3` into `app/assets/audio/` and we add a file player (audioplayers / just_audio) that
  prefers the clip and falls back to TTS.

## Letter-syllables render **linked**
Non-picturable syllables (`and`, `for`, `ing`, `-s`…) are drawn by `SyllableTile`
(`app/lib/content/syllable_tile.dart`): the letters are tightly set and bound by one continuous
underline bar, so the syllable reads as **one whole sound-piece** — distinct from the separated letters
of the alphabet stage. (Prefer literal joined-cursive letters instead of the connector bar? We can swap
in a connected-script font.)

## Image spec
- 512×512 PNG exported from an SVG master; transparent background.
- Bold, flat, high-contrast line-art; one instantly-recognizable subject.
- Consistent stroke weight + palette; discriminable at thumbnail size and for color-blind users.
- Filename = the element `id` (`cat.png`). Full style guide: [`symbol-art-strategy.md`](symbol-art-strategy.md).

## Audio spec
- Mono, loudness-normalized; ~0.6–1.2s syllables, ~1–2s words; 44.1kHz mp3/m4a.
- Warm, clear, child-directed voice. TTS placeholders acceptable to bootstrap.
- Filename = the `audio_ref` (`cat.mp3`, `word_open.mp3`).

## Producing assets
1. `node content/gen-asset-manifest.mjs` → `content/asset-manifest.json` (full list + target paths).
2. Create each image/clip to spec (commission, AI-assisted + human cleanup, or a VO session).
3. Drop files into `app/assets/images/pictographs/` and `app/assets/audio/`.
4. Rebuild — `GlyphView` picks up images automatically.
5. `node content/validate.mjs content/content_bank.v1.json` warns for any still-missing asset.

## Status
- Plumbing, folders, manifest, specs, linked-letter rendering: **ready**.
- Placeholders in use: **emoji** (images) + **on-device TTS** (audio).
- Next: produce real pictographs + audio; adopt `GlyphView` at the remaining render sites; add the
  audio file-player.
