#!/usr/bin/env node
// Validates the shipped Content Bank (content_bank.v1.json by default; pass a
// path to validate another, e.g. the v0 seed bank):
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
  : join(scriptDir, 'content_bank.v1.json');

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

// ── phonemes (optional sibling phonemes.v1.json) ─────────────────────────────
const phonemesPath = join(dirname(bankPath), 'phonemes.v1.json');
if (existsSync(phonemesPath)) {
  let ph = { phonemes: [] };
  try {
    ph = JSON.parse(readFileSync(phonemesPath, 'utf8'));
  } catch (e) {
    err(`phonemes: could not parse ${phonemesPath}: ${e.message}`);
  }
  const picturableIds = new Set(elements.filter((e) => e.picturable).map((e) => e.id));
  const inv = new Set();
  for (const [i, p] of (ph.phonemes ?? []).entries()) {
    const at = `phonemes[${i}]${p?.ipa ? ` (${p.ipa})` : ''}`;
    if (!isNonEmptyString(p?.ipa)) { err(`${at}: missing "ipa"`); continue; }
    if (inv.has(p.ipa)) err(`${at}: duplicate ipa`);
    inv.add(p.ipa);
    if (typeof p.stop !== 'boolean') err(`${at}: "stop" must be boolean`);
    if (!picturableIds.has(p.anchor)) {
      err(`${at}: anchor "${p.anchor}" is not a picturable element`);
    }
  }
  // Every phoneme produced by a grapheme must be in the inventory (ks = k + s).
  const used = new Set();
  for (const el of elements) {
    for (const g of el.graphemes ?? []) {
      if (g.p === 'ks') { used.add('k'); used.add('s'); } else used.add(g.p);
    }
  }
  for (const p of used) {
    if (!inv.has(p)) err(`phonemes: grapheme phoneme "${p}" missing from inventory`);
  }
  console.log(`Phoneme inventory v${ph.version ?? '?'}: ${inv.size} phonemes, ${used.size} used by graphemes`);

  // Rhyme groups must be sound-based: members share their rime (the phonemes
  // from the first vowel onward). This catches spelling-rhymes like snow/cow.
  const vowels = new Set(
    (ph.phonemes ?? []).filter((p) => ['vowel', 'diphthong'].includes(p.kind)).map((p) => p.ipa));
  const rimeOf = (el) => {
    const gs = el.graphemes ?? [];
    let i = gs.findIndex((g) => vowels.has(g.p));
    if (i < 0) i = 0;
    return gs.slice(i).map((g) => g.p).join('');
  };
  const byRhyme = new Map();
  for (const el of elements) {
    if (!el.picturable || !el.rhyme_group || !(el.graphemes ?? []).length) continue;
    if (!byRhyme.has(el.rhyme_group)) byRhyme.set(el.rhyme_group, []);
    byRhyme.get(el.rhyme_group).push(el);
  }
  for (const [grp, members] of byRhyme) {
    if (members.length < 2) continue;
    if (new Set(members.map(rimeOf)).size > 1) {
      err(`rhyme_group "${grp}": members don't share a rime sound — ${members.map((m) => `${m.id}=/${rimeOf(m)}/`).join(', ')}`);
    }
  }
}

// ── curriculum schedule (optional sibling curriculum.v1.json) ────────────────
const curriculumPath = join(dirname(bankPath), 'curriculum.v1.json');
if (existsSync(curriculumPath)) {
  let cur = { levels: [] };
  try {
    cur = JSON.parse(readFileSync(curriculumPath, 'utf8'));
  } catch (e) {
    err(`curriculum: could not parse ${curriculumPath}: ${e.message}`);
  }
  const KNOWN_GAMES = new Set([
    'listen_and_pick', 'find_the_character', 'sound_match', 'families', 'build_a_word', 'fill_blank',
    'picture_to_word', 'symbol_hunt', 'echo_read', 'blend_reveal',
    'story_time', 'hidden_glyph', 'feed_the_guide', 'build_a_sentence', 'rebus_quest']);
  const introduced = new Set();
  for (const lv of cur.levels ?? []) {
    for (const id of lv.introduce ?? []) {
      if (!elementIds.has(id)) err(`curriculum L${lv.id}: introduce "${id}" is not an element`);
      if (introduced.has(id)) err(`curriculum L${lv.id}: "${id}" introduced twice`);
      introduced.add(id);
    }
    for (const g of lv.games ?? []) {
      if (!KNOWN_GAMES.has(g)) err(`curriculum L${lv.id}: unknown game "${g}"`);
    }
  }
  // Units must partition their levels: every referenced level exists, none twice.
  const inUnit = new Set();
  const levelIds = new Set((cur.levels ?? []).map((l) => l.id));
  for (const u of cur.units ?? []) {
    for (const id of u.levels ?? []) {
      if (!levelIds.has(id)) err(`curriculum unit ${u.id}: level ${id} does not exist`);
      if (inUnit.has(id)) err(`curriculum unit ${u.id}: level ${id} in two units`);
      inUnit.add(id);
    }
  }
  if ((cur.units ?? []).length > 0) {
    for (const id of levelIds) {
      if (!inUnit.has(id)) err(`curriculum: level ${id} belongs to no unit`);
    }
  }
  // story:true requires an actually-unlocked story at that level.
  const storiesSibling = join(dirname(bankPath), 'stories.v1.json');
  if (existsSync(storiesSibling)) {
    try {
      const st = JSON.parse(readFileSync(storiesSibling, 'utf8'));
      const unlocks = (st.stories ?? []).map((s) => s.unlock_level ?? 1);
      for (const lv of cur.levels ?? []) {
        if (lv.story && !unlocks.some((u) => u <= lv.id)) {
          err(`curriculum L${lv.id}: story:true but no story unlocks by level ${lv.id}`);
        }
      }
    } catch { /* parse errors already reported by the stories section */ }
  }
  for (const e of elements) {
    if (e.picturable && !introduced.has(e.id)) {
      warn(`curriculum: pictograph "${e.id}" is never introduced`);
    }
  }
  console.log(`Curriculum v${cur.version ?? '?'}: ${(cur.levels ?? []).length} levels, ${introduced.size} symbols introduced`);
}

// ── stories (optional sibling stories.v1.json) ──────────────────────────────
const storiesPath = join(dirname(bankPath), 'stories.v1.json');
if (existsSync(storiesPath)) {
  let st = { stories: [] };
  try {
    st = JSON.parse(readFileSync(storiesPath, 'utf8'));
  } catch (e) {
    err(`stories: could not parse ${storiesPath}: ${e.message}`);
  }
  const seen = new Set();
  for (const s of st.stories ?? []) {
    if (seen.has(s.id)) err(`stories ${s.id}: duplicate id`);
    seen.add(s.id);
    if (!Number.isInteger(s.unlock_level) || s.unlock_level < 1) {
      err(`stories ${s.id}: unlock_level must be a positive integer`);
    }
    if (!Array.isArray(s.lines) || s.lines.length === 0) {
      err(`stories ${s.id}: needs at least one line`);
    }
    for (const line of s.lines ?? []) {
      for (const id of line) {
        if (!elementIds.has(id)) err(`stories ${s.id}: token "${id}" is not an element`);
      }
    }
  }
  console.log(`Stories v${st.version ?? '?'}: ${(st.stories ?? []).length} stories`);
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
