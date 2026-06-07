import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/build_a_word/build_a_word_page.dart';
import 'features/find_the_character/find_the_character_page.dart';
import 'features/games_menu/games_menu_page.dart';
import 'features/listen_and_pick/listen_and_pick_page.dart';
import 'features/pictograph_demo/pictograph_demo_page.dart';
import 'progress/firestore_progress_store.dart';
import 'progress/local_progress_store.dart';
import 'progress/progress_service.dart';
import 'progress/progress_store.dart';
import 'services/audio_service.dart';
import 'services/content_service.dart';

// Dev flag: `flutter run --dart-define=USE_FIRESTORE_EMULATOR=true` runs against
// the local Firebase emulator suite (no real project needed).
const bool _useFirestoreEmulator = bool.fromEnvironment('USE_FIRESTORE_EMULATOR');

// Emulator-only Firebase config (the "demo-" project id is emulator-only).
// Production uses flutterfire-generated options instead — see docs/firebase-setup.md.
const FirebaseOptions _emulatorOptions = FirebaseOptions(
  apiKey: 'demo',
  appId: '1:0:android:demo',
  messagingSenderId: '0',
  projectId: 'demo-reading-game',
);

void main() {
  runApp(const ReadingGameApp());
}

class ReadingGameApp extends StatefulWidget {
  const ReadingGameApp({super.key});

  @override
  State<ReadingGameApp> createState() => _ReadingGameAppState();
}

class _ReadingGameAppState extends State<ReadingGameApp>
    with WidgetsBindingObserver {
  final ContentService _contentService = const ContentService();
  final AudioService _audioService = TtsAudioService();
  ProgressService? _progress;
  late final Future<ProgressService> _init = _setup();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist immediately when the app goes to the background.
    if (state == AppLifecycleState.paused) _progress?.flush();
  }

  Future<ProgressService> _setup() async {
    final bank = await _contentService.load();
    final store = await _pickStore();
    final progress =
        ProgressService(bank: bank, store: store, profileId: 'default');
    await progress.restore();
    _progress = progress;
    return progress;
  }

  // Use Firestore when available; otherwise on-device local persistence so the
  // app works without a configured backend.
  Future<ProgressStore> _pickStore() async {
    try {
      if (_useFirestoreEmulator) {
        await Firebase.initializeApp(options: _emulatorOptions);
        FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
        await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
        final cred = await FirebaseAuth.instance.signInAnonymously();
        return FirestoreProgressStore(uid: cred.user!.uid);
      }
      await Firebase.initializeApp(); // throws if no native config present
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) return FirestoreProgressStore(uid: uid);
    } catch (_) {
      // Firebase not configured in this build — fall back to local persistence.
    }
    return const LocalProgressStore();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reading Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F7CAC)),
        useMaterial3: true,
      ),
      home: FutureBuilder<ProgressService>(
        future: _init,
        builder: (context, snapshot) {
          final progress = snapshot.data;
          if (progress == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // Games stay decoupled: they only emit LearningEvents via onEvent.
          final games = <GameEntry>[
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
                onEvent: progress.record,
              ),
            ),
            GameEntry(
              title: 'Build a Word',
              subtitle: 'Blend syllables into a word',
              icon: Icons.extension,
              builder: (_) => BuildAWordPage(
                contentService: _contentService,
                audioService: _audioService,
                onEvent: progress.record,
              ),
            ),
            GameEntry(
              title: 'Find the Character',
              subtitle: 'Read a word, find the picture',
              icon: Icons.search,
              builder: (_) => FindTheCharacterPage(
                contentService: _contentService,
                audioService: _audioService,
                onEvent: progress.record,
              ),
            ),
          ];
          return GamesMenuPage(games: games, progress: progress);
        },
      ),
    );
  }
}
