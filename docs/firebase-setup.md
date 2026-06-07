# Firebase setup (owner-run)

These steps require **your Google account** and create billable cloud resources, so **you** run them —
they are intentionally *not* automated in this repo. The repo already contains all config files,
security rules, and the Functions code; this guide wires them to a live project.

> Repo-side files already present: [`../backend/firebase.json`](../backend/firebase.json),
> [`.firebaserc`](../backend/.firebaserc), [`firestore.rules`](../backend/firestore.rules),
> [`firestore.indexes.json`](../backend/firestore.indexes.json),
> [`storage.rules`](../backend/storage.rules), and
> [`functions/`](../backend/functions/).

## 0. Install tooling (once)

```bash
npm install -g firebase-tools          # Firebase CLI
dart pub global activate flutterfire_cli # FlutterFire CLI (adds ~/.pub-cache/bin to PATH)
firebase --version && flutterfire --version
```

## 1. Log in & create projects

```bash
firebase login
```
In the [Firebase console](https://console.firebase.google.com/), create **two** projects (recommended):
`reading-game-dev` and `reading-game-prod`. Then map them to the aliases this repo expects:

```bash
cd backend
firebase use --add        # pick reading-game-dev → alias "dev"
firebase use --add        # pick reading-game-prod → alias "prod"
firebase use dev
```
This updates [`.firebaserc`](../backend/.firebaserc) (placeholder project ids are replaced).

## 2. Generate the app's Firebase config

From the **app** directory, let FlutterFire generate `lib/firebase_options.dart` and the native config
files (these are **gitignored** by design):

```bash
cd ../app
flutterfire configure --project=reading-game-dev
```

## 3. Enable Auth providers

Console → **Authentication → Sign-in method**: enable **Email/Password**, **Google**, and
**Apple** (Apple is required by the App Store when any social login is offered).

## 4. Set the Claude API key (server-side secret)

Never put the key in the repo. Store it as a Functions secret:

```bash
cd ../backend
firebase functions:secrets:set ANTHROPIC_API_KEY    # paste your Anthropic key when prompted
```
[`functions/.env.example`](../backend/functions/.env.example) documents the variable name only.

## 5. Run locally with the Emulator Suite

```bash
cd backend
firebase emulators:start          # Auth + Firestore + Functions
# in another terminal:
cd ../app && flutter run
```
The Story Builder function returns a **canned** vocabulary-constrained story when no key is configured,
so you can test the flow against emulators without spending tokens.

### Exercising progress persistence against Firestore

Per-child progress is saved through a small `ProgressStore` seam
([`app/lib/progress/`](../app/lib/progress/)): `LocalProgressStore`
(`shared_preferences` — the default when no backend is configured) and
`FirestoreProgressStore` (`/parents/{uid}/children/{profileId}/state/progress`, matching
[`firestore.rules`](../backend/firestore.rules)). To exercise the **Firestore** path
without a real project, run against the emulators in fully-offline demo mode:

```bash
cd backend
firebase emulators:start --only auth,firestore --project demo-reading-game
# in another terminal:
cd ../app && flutter run --dart-define=USE_FIRESTORE_EMULATOR=true
```

The `demo-` project prefix keeps everything offline (no credentials, no billing). The app
signs in anonymously to the Auth emulator and reads/writes the Firestore emulator; force-stop
and relaunch, and progress is restored from Firestore rather than local storage.

- **Android cleartext:** the app reaches the host emulators at `10.0.2.2` over plain HTTP/gRPC,
  which Android blocks by default (API 28+). A **debug-only** allowance lives at
  [`app/android/app/src/debug/res/xml/network_security_config.xml`](../app/android/app/src/debug/res/xml/network_security_config.xml) —
  release builds keep the block. (A physical device would use the host's LAN IP, not `10.0.2.2`.)
- **Inspect emulator data** with the admin token (`Bearer owner` bypasses the security rules):
  ```bash
  # the saved progress document:
  curl -H "Authorization: Bearer owner" \
    "http://127.0.0.1:8080/v1/projects/demo-reading-game/databases/(default)/documents/parents/<uid>/children/default/state/progress"
  # the anonymous user(s) the app created:
  curl -X POST -H "Authorization: Bearer owner" -H "Content-Type: application/json" -d '{}' \
    "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/projects/demo-reading-game/accounts:query"
  ```
- Or browse the **Emulator UI** at <http://127.0.0.1:4000/>.

## 6. Deploy (when ready)

```bash
cd backend
firebase deploy --only firestore:rules,storage,functions   # to the current alias (dev/prod)
```

## Notes

- Switch targets with `firebase use dev` / `firebase use prod`.
- Re-run `flutterfire configure` whenever you add a platform or a new Firebase project.
- Keep `firebase_options.dart`, `google-services.json`, and `GoogleService-Info.plist` **out of git**
  (already in [`.gitignore`](../.gitignore)).
