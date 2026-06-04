// EXAMPLE ONLY — not used by the app. `flutterfire configure` generates the real
// lib/firebase_options.dart (which is gitignored). This file documents the shape
// so reviewers know what to expect. See docs/firebase-setup.md.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _placeholder;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return _placeholder;
      default:
        throw UnsupportedError(
          'Run `flutterfire configure` to generate a real firebase_options.dart.',
        );
    }
  }

  // Placeholder values — replaced by `flutterfire configure`.
  static const FirebaseOptions _placeholder = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'reading-game-dev',
  );
}
