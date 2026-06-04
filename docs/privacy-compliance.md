# Privacy & compliance

This is a product **for young children**, so privacy and safety are design constraints from day one —
not a pre-launch checklist. This document is engineering guidance, **not legal advice**; a qualified
attorney must review before any public release.

## Regulations in scope

- **COPPA** (US) — children under 13.
- **GDPR-K** (EU) — children's data; age of consent varies 13–16 by member state.
- **Apple Kids Category** & **Google Families** policies — store-level rules for kids' apps.

## Principles

1. **No child PII.** Children never create accounts or enter names/emails. A child profile is a
   parent-created **nickname + avatar + progress** only.
2. **Parent-gated.** Account creation, settings, purchases, and any external links sit behind a
   **parental gate** (e.g. a math/hold gate). Only **parents** authenticate (email / Google / Apple).
3. **Data minimization.** Collect only what the learning loop needs (mastery/progress). No contact
   lists, precise location, photos, or microphone unless a feature requires it with explicit consent.
4. **No behavioral advertising. No third-party ad SDKs. No selling data.**
5. **Verifiable parental consent** where required before any data collection beyond internal support of
   the activity.
6. **Analytics are privacy-safe:** aggregate learning events only; no cross-app tracking, no advertising
   identifiers. Configure Analytics/Crashlytics accordingly (or gate them behind consent).
7. **Transparency:** clear, child-appropriate and parent-facing privacy policy; documented
   **retention** and **deletion** (parent can delete a child profile and all its data).

## LLM-specific safety (Story Builder)

- The LLM is reached **only** through the server-side proxy; the API key never ships in the app.
- **No child PII is sent to the model** — inputs are story-starter choices and learned-vocabulary ids.
- Output is **vocabulary-whitelisted** and **safety-filtered** server-side; nothing unvalidated reaches
  the screen (see [`architecture.md`](architecture.md)).
- Log prompts/outputs for safety review **without** child identifiers; short retention.

## Security posture

- **App Check** on all callable functions; **least-privilege** Firestore rules (parent-scoped).
- Secrets only via `firebase functions:secrets:set`; nothing sensitive in git (enforced by
  [`.gitignore`](../.gitignore)).
- Sign in with Apple offered wherever another social login is (App Store requirement).

## Open items (track toward M5)

- [ ] Legal review of privacy policy, consent flow, and data map.
- [ ] Decide Analytics/Crashlytics consent model (off-by-default vs consented).
- [ ] Data Subject Request / deletion workflow.
- [ ] Store-listing compliance (Kids Category / Families) checklist.
