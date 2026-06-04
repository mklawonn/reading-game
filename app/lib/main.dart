import 'package:flutter/material.dart';

import 'features/build_a_word/build_a_word_page.dart';
import 'features/find_the_character/find_the_character_page.dart';
import 'features/games_menu/games_menu_page.dart';
import 'features/listen_and_pick/listen_and_pick_page.dart';
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

  // The registry of play modes shown on the home menu. Adding a game is one
  // GameEntry here — the menu and the games stay decoupled.
  late final List<GameEntry> _games = [
    GameEntry(
      title: 'Tap to Hear',
      subtitle: 'Hear each picture',
      icon: Icons.touch_app,
      builder: (_) => PictographDemoPage(
        contentService: _contentService,
        audioService: _audioService,
      ),
    ),
    GameEntry(
      title: 'Listen & Pick',
      subtitle: 'Tap what you hear',
      icon: Icons.hearing,
      builder: (_) => ListenAndPickPage(
        contentService: _contentService,
        audioService: _audioService,
      ),
    ),
    GameEntry(
      title: 'Build a Word',
      subtitle: 'Blend syllables into a word',
      icon: Icons.extension,
      builder: (_) => BuildAWordPage(
        contentService: _contentService,
        audioService: _audioService,
      ),
    ),
    GameEntry(
      title: 'Find the Character',
      subtitle: 'Read a word, find the picture',
      icon: Icons.search,
      builder: (_) => FindTheCharacterPage(
        contentService: _contentService,
        audioService: _audioService,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7CAC)),
        useMaterial3: true,
      ),
      home: GamesMenuPage(games: _games),
    );
  }
}
