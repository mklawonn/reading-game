#!/usr/bin/env node
// Generates content/asset-manifest.json: the production worklist of every
// pictograph image and audio clip the Content Bank needs. Feeds illustrators /
// voice work / asset-generation. Usage: node content/gen-asset-manifest.mjs [bank.json]

import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, join } from 'node:path';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const bankPath = process.argv[2]
  ? resolve(process.argv[2])
  : join(scriptDir, 'content_bank.v1.json');

const bank = JSON.parse(readFileSync(bankPath, 'utf8'));
const ap = bank.asset_paths;

// Pictograph images — one per picturable element (words reuse the element image).
const images = [];
const seenImg = new Set();
for (const el of bank.elements) {
  if (el.picturable && el.image_ref && !seenImg.has(el.image_ref)) {
    seenImg.add(el.image_ref);
    images.push({
      id: el.id,
      label: el.syllable,
      asset: ap.images + el.image_ref,
      path: ap.base + ap.images + el.image_ref,
    });
  }
}

// Audio clips — one per element syllable + one per word.
const audio = [];
const seenAud = new Set();
const addAudio = (ref, kind, text) => {
  if (!ref || seenAud.has(ref)) return;
  seenAud.add(ref);
  audio.push({ ref, kind, text, asset: ap.audio + ref, path: ap.base + ap.audio + ref });
};
for (const el of bank.elements) addAudio(el.audio_ref, 'syllable', el.syllable);
for (const w of bank.words) addAudio(w.audio_ref, 'word', w.text);

const manifest = {
  version: bank.version,
  generatedFrom: `content_bank.v${bank.version}.json`,
  summary: { pictographImages: images.length, audioClips: audio.length },
  imageSpec:
    '512x512 PNG exported from an SVG master; transparent background; bold flat ' +
    'line-art, high contrast, one clear subject. See docs/symbol-art-strategy.md.',
  audioSpec:
    'Mono, loudness-normalized; ~0.6-1.2s for syllables, ~1-2s for words; 44.1kHz ' +
    'mp3/m4a; warm child-directed voice. TTS placeholders acceptable to start.',
  images,
  audio,
};

const outPath = join(scriptDir, 'asset-manifest.json');
writeFileSync(outPath, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`Wrote ${outPath}`);
console.log(`  pictograph images needed: ${images.length}`);
console.log(`  audio clips needed:       ${audio.length}`);
