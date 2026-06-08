#!/usr/bin/env node
// Validates content/content_bank.v0.json:
//  - ERRORS (exit 1): malformed JSON, missing/!valid fields, duplicate ids,
//    unresolved segmentation refs, picturable element missing image_ref.
//  - WARNINGS (exit 0): referenced image/audio asset not present on disk
//    (expected during M0, where assets are placeholders).
//
// Usage: node content/validate.mjs [path-to-bank.json]

import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(scriptDir, '..');
const bankPath = process.argv[2]
  ? resolve(process.argv[2])
  : join(scriptDir, 'content_bank.v0.json');

const errors = [];
const warnings = [];
const err = (m) => errors.push(m);
const warn = (m) => warnings.push(m);

const VALID_TYPES = new Set(['pictograph', 'glyph', 'letter_array', 'letter']);

function isNonEmptyString(v) {
  return typeof v === 'string' && v.length > 0;
}

let bank;
try {
  bank = JSON.parse(readFileSync(bankPath, 'utf8'));
} catch (e) {
  console.error(`✖ Could not parse ${bankPath}\n  ${e.message}`);
  process.exit(1);
}

for (const f of ['version', 'source', 'asset_paths', 'stages', 'elements', 'words']) {
  if (!(f in bank)) err(`top-level: missing required field "${f}"`);
}
const ap = bank.asset_paths ?? {};
for (const f of ['base', 'images', 'audio']) {
  if (!isNonEmptyString(ap[f])) err(`asset_paths: missing/invalid "${f}"`);
}

const elements = Array.isArray(bank.elements) ? bank.elements : [];
const words = Array.isArray(bank.words) ? bank.words : [];

const elementIds = new Set();
const imageFull = (ref) => join(repoRoot, ap.base ?? '', ap.images ?? '', ref);
const audioFull = (ref) => join(repoRoot, ap.base ?? '', ap.audio ?? '', ref);

// ── elements ──────────────────────────────────────────────────────────────
for (const [i, el] of elements.entries()) {
  const at = `elements[${i}]${el?.id ? ` (${el.id})` : ''}`;
  if (!isNonEmptyString(el?.id)) { err(`${at}: missing "id"`); continue; }
  if (elementIds.has(el.id)) err(`${at}: duplicate element id`);
  elementIds.add(el.id);

  if (!VALID_TYPES.has(el.type)) err(`${at}: invalid type "${el.type}"`);
  for (const f of ['syllable', 'sound_ipa', 'audio_ref']) {
    if (el[f] !== null && !isNonEmptyString(el[f])) err(`${at}: missing/invalid "${f}"`);
  }
  if (typeof el.picturable !== 'boolean') err(`${at}: "picturable" must be boolean`);
  if (el.picturable && !isNonEmptyString(el.image_ref)) {
    err(`${at}: picturable element must have "image_ref"`);
  }
  if (isNonEmptyString(el.image_ref) && !existsSync(imageFull(el.image_ref))) {
    warn(`${at}: image_ref not on disk yet → ${el.image_ref}`);
  }
  if (isNonEmptyString(el.audio_ref) && !existsSync(audioFull(el.audio_ref))) {
    warn(`${at}: audio_ref not on disk yet → ${el.audio_ref}`);
  }

  // Graphemes (optional): the letter-groups must reconstruct the spelling and
  // their phonemes must reconstruct sound_ipa — the Stage-4 decoding invariant.
  if (el.graphemes !== undefined) {
    if (!Array.isArray(el.graphemes) || el.graphemes.length === 0) {
      err(`${at}: "graphemes" must be a non-empty array`);
    } else {
      let letters = '', phonemes = '';
      for (const g of el.graphemes) {
        if (!isNonEmptyString(g?.g) || !isNonEmptyString(g?.p)) {
          err(`${at}: each grapheme needs non-empty "g" and "p"`);
        } else { letters += g.g; phonemes += g.p; }
      }
      if (letters.toLowerCase() !== String(el.syllable).toLowerCase()) {
        err(`${at}: graphemes spell "${letters}" ≠ syllable "${el.syllable}"`);
      }
      if (phonemes !== el.sound_ipa) {
        err(`${at}: graphemes sound "${phonemes}" ≠ sound_ipa "${el.sound_ipa}"`);
      }
    }
  }
}

// ── words ─────────────────────────────────────────────────────────────────
const resolveIds = (ids, at, field) => {
  if (!Array.isArray(ids)) { err(`${at}: "${field}" must be an array`); return; }
  for (const id of ids) {
    if (!elementIds.has(id)) err(`${at}: "${field}" references unknown element "${id}"`);
  }
};

const wordIds = new Set();
for (const [i, w] of words.entries()) {
  const at = `words[${i}]${w?.id ? ` (${w.id})` : ''}`;
  if (!isNonEmptyString(w?.id)) { err(`${at}: missing "id"`); continue; }
  if (wordIds.has(w.id)) err(`${at}: duplicate word id`);
  wordIds.add(w.id);

  if (!isNonEmptyString(w.text)) err(`${at}: missing "text"`);
  if (!Array.isArray(w.segmentation) || w.segmentation.length < 1) {
    err(`${at}: "segmentation" must be a non-empty array`);
  } else {
    resolveIds(w.segmentation, at, 'segmentation');
  }
  for (const seg of w.alt_segmentation ?? []) resolveIds(seg, at, 'alt_segmentation');

  if (typeof w.picturable !== 'boolean') err(`${at}: "picturable" must be boolean`);
  if (w.picturable && !isNonEmptyString(w.image_ref)) {
    err(`${at}: picturable word must have "image_ref"`);
  }
  if (isNonEmptyString(w.image_ref) && !existsSync(imageFull(w.image_ref))) {
    warn(`${at}: image_ref not on disk yet → ${w.image_ref}`);
  }
  if (isNonEmptyString(w.audio_ref) && !existsSync(audioFull(w.audio_ref))) {
    warn(`${at}: audio_ref not on disk yet → ${w.audio_ref}`);
  }
}

// ── report ──────────────────────────────────────────────────────────────────
console.log(`Content Bank v${bank.version ?? '?'}: ${elements.length} elements, ${words.length} words`);
if (warnings.length) {
  console.log(`\n⚠ ${warnings.length} warning(s) (asset placeholders expected in M0):`);
  const shown = warnings.slice(0, 5);
  for (const w of shown) console.log(`  · ${w}`);
  if (warnings.length > shown.length) console.log(`  · …and ${warnings.length - shown.length} more`);
}
if (errors.length) {
  console.error(`\n✖ ${errors.length} error(s):`);
  for (const e of errors) console.error(`  · ${e}`);
  process.exit(1);
}
console.log('\n✓ Content Bank is valid.');
process.exit(0);
