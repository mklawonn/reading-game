import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/build_a_word/build_a_word_page.dart';
import 'features/families/families_page.dart';
import 'features/fill_blank/fill_blank_page.dart';
import 'features/find_the_character/find_the_character_page.dart';
import 'features/games_menu/games_menu_page.dart';
import 'features/listen_and_pick/listen_and_pick_page.dart';
import 'features/pictograph_demo/pictograph_demo_page.dart';
import 'features/profile/create_profile_screen.dart';
import 'features/profile/profile_chooser_screen.dart';
import 'features/sound_match/sound_match_page.dart';
import 'learning/item_sampler.dart';
import 'models/content_bank.dart';
import 'profile/local_profile_store.dart';
import 'profile/profile.dart';
import 'profile/profile_store.dart';
import 'progress/firestore_progress_store.dart';
import 'progress/local_progress_store.dart';
import 'progress/progress_service.dart';
import 'progress/progress_store.dart';
import 'services/audio_service.dart';
import 'services/content_service.dart';

// Dev flag: `flutter run --dart-define=USE_FIRESTORE_EMULATOR=true` runs against
// the local Firebase emulator suite (no real project needed).
const bool _useFirestoreEmulator = bool.fromEnvironment('USE_FIRESTORE_EMULATOR');

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
  final ProfileStore _profileStore = const LocalProfileStore();

  ContentBank? _bank;
  ProgressStore? _store; // shared; per-profile state is keyed by profile id
  ProfileData _profiles = const ProfileData();
  ProgressService? _progress; // the active profile's progress
  bool _loading = true;
  bool _addingProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
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

  Future<void> _bootstrap() async {
    _bank = await _contentService.load();
    _store = await _pickStore();
    _profiles = await _profileStore.load();
    final active = _profiles.active;
    if (active != null) _progress = await _buildProgress(active);
    if (mounted) setState(() => _loading = false);
  }

  Future<ProgressService> _buildProgress(Profile p) async {
    final progress =
        ProgressService(bank: _bank!, store: _store!, profileId: p.id);
    await progress.restore();
    return progress;
  }

  /// Make [p] the active profile (creating it if [isNew]) and load its progress.
  Future<void> _activate(Profile p, {required bool isNew}) async {
    final list = isNew ? [..._profiles.profiles, p] : _profiles.profiles;
    final data = _profiles.copyWith(profiles: list, activeId: p.id);
    await _profileStore.save(data);
    final progress = await _buildProgress(p);
    if (!mounted) return;
    setState(() {
      _profiles = data;
      _progress = progress;
      _addingProfile = false;
    });
  }

  /// Return to the profile chooser (flushes the active profile first).
  Future<void> _switchProfile() async {
    await _progress?.flush();
    final data = _profiles.copyWith(activeId: null);
    await _profileStore.save(data);
    if (!mounted) return;
    setState(() {
      _profiles = data;
      _progress = null;
      _addingProfile = false;
    });
  }

  // Use Firestore when available; otherwise on-device local persistence.
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
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final progress = _progress;
    if (progress != null) return _menu(progress);

    // No active profile → create (first run / "add") or choose.
    if (_profiles.profiles.isEmpty || _addingProfile) {
      return CreateProfileScreen(
        onCreate: (p) => _activate(p, isNew: true),
        onBack: _profiles.profiles.isEmpty
            ? null
            : () => setState(() => _addingProfile = false),
      );
    }
    return ProfileChooserScreen(
      profiles: _profiles.profiles,
      onSelect: (p) => _activate(p, isNew: false),
      onAdd: () => setState(() => _addingProfile = true),
    );
  }

  // The current launcher (replaced by the guided level-map home in a later phase).
  Widget _menu(ProgressService progress) {
    final sampler = ItemSampler(progress);
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
          sampler: sampler,
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
          sampler: sampler,
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
          sampler: sampler,
          onEvent: progress.record,
        ),
      ),
      GameEntry(
        title: 'Sound Match',
        subtitle: 'Match each picture to its sound',
        icon: Icons.graphic_eq,
        builder: (_) => SoundMatchPage(
          contentService: _contentService,
          audioService: _audioService,
          sampler: sampler,
          onEvent: progress.record,
        ),
      ),
      GameEntry(
        title: 'Fill the Blank',
        subtitle: 'Add the missing word',
        icon: Icons.edit_note,
        builder: (_) => FillBlankPage(
          contentService: _contentService,
          audioService: _audioService,
          stage: progress.currentStage,
          sampler: sampler,
          onEvent: progress.record,
        ),
      ),
      GameEntry(
        title: 'Sound Families',
        subtitle: 'Match by rhyme or first sound',
        icon: Icons.workspaces,
        builder: (_) => FamiliesPage(
          contentService: _contentService,
          audioService: _audioService,
          sampler: sampler,
          onEvent: progress.record,
        ),
      ),
    ];
    return GamesMenuPage(
      games: games,
      progress: progress,
      profile: _profiles.active,
      onSwitchProfile: _switchProfile,
    );
  }
}
