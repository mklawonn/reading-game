# Content Bank schema

The Content Bank is the **single source of truth** for every symbol and word in the game. It is a JSON
document with two collections — **`elements`** (atomic syllable-symbols) and **`words`** (single
elements or blends of elements). The selection rationale behind the data lives in
[`../docs/content-bank-strategy.md`](../docs/content-bank-strategy.md).

Validate with: `node content/validate.mjs`.

## Top-level

| Field | Type | Notes |
|---|---|---|
| `version` | string | Bank version (`"0"` = paper seed). |
| `source` | string | Provenance. |
| `notes` | string | Caveats for this version. |
| `asset_paths` | object | Base dirs for `image_ref` / `audio_ref` (relative to `app/assets/`). |
| `stages` | object | Stage id → name. |
| `elements` | array | Atomic syllable-symbols (see below). |
| `words` | array | Words; each `segmentation` references `elements[].id`. |

## `elements[]`

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique, kebab/lower. Referenced by `words[].segmentation`. |
| `type` | enum | `pictograph` \| `glyph` \| `letter_array` \| `letter` (the symbol tier). |
| `syllable` | string | Spelling of the syllable. |
| `sound_ipa` | string | Best-effort General American IPA for the syllable in isolation. |
| `picturable` | bool | True ⇒ should have a pictograph; must then have `image_ref`. |
| `image_ref` | string\|null | Path under `asset_paths.images` (may not exist yet in M0). |
| `audio_ref` | string\|null | Path under `asset_paths.audio` for the syllable sound. |
| `continuant` | bool | Begins with a continuant consonant (s,f,m,n,z,l,r,…) — Stage-3 relevance. |
| `rhyme_group` | string\|null | Coarse rime tag (e.g. `an`, `ee`) for rhyme families. |
| `introduced_stage` | int | Earliest stage this element appears. |
| `frequency` | object | `{ dolch_tier: string\|null, fry_rank: int\|null }` — reference signal only. |
| `decomposition_cost` | int | 1 (low) … 3 (high). |
| `graphemes` | array\|absent | Optional letter-group→phoneme decoding map: `[{ "g": "ai", "p": "eɪ" }, …]`. Concatenated `g` must equal `syllable`, concatenated `p` must equal `sound_ipa` (enforced by `validate.mjs`). Present for decodable picturable words; powers Stage-4. Multi-letter graphemes (`ee`, `ng`) are one unit; `x`→`ks` is one letter mapping to two phonemes. |
| `notes` | string | Free notes (e.g. rebus explanation). |

## `words[]`

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique, lower. |
| `text` | string | The word as displayed/spoken. |
| `segmentation` | string[] | ≥1 `elements[].id` whose sounds blend to the word. **Must all resolve.** |
| `picturable` | bool | Can the whole word be one pictograph? |
| `image_ref` | string\|null | Optional word-level picture. |
| `audio_ref` | string\|null | Path for the word pronunciation. |
| `story_tags` | string[] | e.g. `function`, `object`, `action` — drives story/game generation. |
| `utility_score` | int | 1 (low) … 3 (high) story/game value. |
| `frequency` | object | `{ dolch_tier, fry_rank }` reference signal. |
| `alt_segmentation` | string[][] | Other valid segmentations (e.g. *candy* = `[[can,d]]` vs `[[cand,y]]`), for Stage-3 phoneme work. |
| `spelling_variants` | string[] | Rule-governed variants (e.g. `sunn` before `-y`). |
| `is_test_blend` | bool | True = held out for assessment (never explicitly taught), per the paper. |
| `inclusion_rationale` | string | One line: why this earns its place. |

## Validator guarantees (`validate.mjs`)

- **Errors** (exit 1): malformed JSON; missing required fields; bad `type`; duplicate ids; any
  `segmentation`/`alt_segmentation` id that does not resolve to an element; a `picturable` element with
  no `image_ref`.
- **Warnings** (exit 0): referenced `image_ref`/`audio_ref` file not present on disk (expected in M0,
  where assets are placeholders).
