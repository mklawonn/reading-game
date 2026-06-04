import 'package:flutter/material.dart';

import 'features/pictograph_demo/pictograph_demo_page.dart';
import 'services/audio_service.dart';
import 'services/content_service.dart';

// ── Firebase ────────────────────────────────────────────────────────────────
// Firebase is scaffolded (firebase_core is a dependency) but intentionally NOT
// initialized in M0, so the app runs without a configured project. After running
// `flutterfire configure` (see docs/firebase-setup.md) to generate
// lib/firebase_options.dart, enable initialization in main():
//
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//
// (See lib/firebase_options.example.dart for the placeholder shape.)

void main() {
  runApp(const ReadingGameApp());
}

class ReadingGameApp extends StatefulWidget {
  const ReadingGameApp({super.key});

  @override
  State<ReadingGameApp> createState() => _ReadingGameAppState();
}

class _ReadingGameAppState extends State<ReadingGameApp> {
  final ContentService _contentService = const ContentService();
  final AudioService _audioService = TtsAudioService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7CAC)),
        useMaterial3: true,
      ),
      home: PictographDemoPage(
        contentService: _contentService,
        audioService: _audioService,
      ),
    );
  }
}
