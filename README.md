# Reading Game

A mobile game that teaches pre-readers to read English by **recapitulating the history of writing** —
pictograph → rebus → syllabary → alphabet — based on Gleitman & Rozin (1973),
*Teaching Reading by Use of a Syllabary* (see [`docs/research/`](docs/research/)).

Children build a profile and progress through five stages, always able to **tap any symbol to hear its
sound**. Play happens in short Duolingo-ABC-style **lessons** — mixed single-round exercises with a
guide character, auto-advance pacing, and starred celebrations (see [`docs/lessons.md`](docs/lessons.md)) —
drawing on ten exercise types from **Listen & Pick** through **Build-a-Word** blending, plus an
LLM-powered **Story Builder** (planned).

> **Status: M0 — Foundations.** This repo currently contains the roadmap, design docs, a seed Content
> Bank, a Firebase scaffold, and a runnable Flutter skeleton that demonstrates the tap-to-hear loop.
> See [`ROADMAP.md`](ROADMAP.md).

## Repository map

| Path | What's here |
|---|---|
| [`ROADMAP.md`](ROADMAP.md) | Phased milestones M0–M5 |
| [`docs/`](docs/) | Curriculum, content & art strategy, game designs, architecture, privacy, Firebase setup |
| [`docs/research/`](docs/research/) | Source papers (Gleitman & Rozin; Dolch list) |
| [`content/`](content/) | The **Content Bank** — single source of truth for symbols/words (`content_bank.v0.json`) + schema + validator |
| [`app/`](app/) | Flutter app (iOS + Android, responsive phone/tablet) |
| [`backend/`](backend/) | Firebase config, security rules, and Cloud Functions (Story Builder Claude proxy) |

## Quickstart

### Prerequisites
- **Flutter SDK** (3.44+) and Dart — https://docs.flutter.dev/get-started/install
- **Node.js** 20+ and npm (for Cloud Functions)
- **Firebase CLI** — `npm i -g firebase-tools`
- **FlutterFire CLI** — `dart pub global activate flutterfire_cli`

### Run the app
```bash
cd app
flutter pub get
flutter run            # or: flutter run -d chrome  (fast preview)
```
You should see a grid of pictograph cards; tapping one plays its sound.

### Content Bank
```bash
node content/validate.mjs   # validate schema + references
```

### Backend (Cloud Functions)
```bash
cd backend/functions
npm install
npm run build
```
Connecting a live Firebase project (Auth, Firestore, Functions, the Claude API key, etc.) is a manual,
owner-run step — follow [`docs/firebase-setup.md`](docs/firebase-setup.md).

## The five-stage curriculum

| Stage | Focus |
|---|---|
| 0 | Listen & blend syllables by ear (pre-print) |
| 1 | **Pictographs** — picturable monosyllables as pictures |
| 2 | **Syllables** — designed symbols + rebus blending into new words |
| 3 | **Phonemes** — continuant consonants, plural -s, rhyme families |
| 4 | **Letters** — the alphabet as an efficient mnemonic for syllables |

Details in [`docs/curriculum.md`](docs/curriculum.md).

## License
Proprietary — see [`LICENSE`](LICENSE). (Placeholder; confirm before any public release.)
