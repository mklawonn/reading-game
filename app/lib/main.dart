import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/home/guided_home_screen.dart';
import 'features/profile/create_profile_screen.dart';
import 'features/profile/profile_chooser_screen.dart';
import 'learning/curriculum_engine.dart';
import 'models/content_bank.dart';
import 'models/curriculum.dart';
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
  CurriculumSchedule? _schedule;
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
    if (state == AppLifecycleState.paused) _progress?.flush();
  }

  Future<void> _bootstrap() async {
    _bank = await _contentService.load();
    _schedule = await _contentService.loadCurriculum();
    _store = await _pickStore();
    _profiles = await _profileStore.load();
    final active = _profiles.active;
    if (active != null) _progress = await _buildProgress(active);
    if (mounted) setState(() => _loading = false);
  }

  Future<ProgressService> _buildProgress(Profile p) async {
    final progress = ProgressService(
      bank: _bank!,
      store: _store!,
      profileId: p.id,
      schedule: _schedule,
    );
    await progress.restore();
    return progress;
  }

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
    if (progress != null) {
      return GuidedHomeScreen(
        progress: progress,
        engine: CurriculumEngine(schedule: _schedule!, bank: _bank!),
        schedule: _schedule!,
        contentService: _contentService,
        audioService: _audioService,
        profile: _profiles.active,
        onSwitchProfile: _switchProfile,
      );
    }

    // No active profile → create (first run / "add") or choose.
    if (_profiles.profiles.isEmpty || _addingProfile) {
      return CreateProfileScreen(
        onCreate: (p) => _activate(p, isNew: true),
        audioService: _audioService,
        onBack: _profiles.profiles.isEmpty
            ? null
            : () => setState(() => _addingProfile = false),
      );
    }
    return ProfileChooserScreen(
      profiles: _profiles.profiles,
      onSelect: (p) => _activate(p, isNew: false),
      onAdd: () => setState(() => _addingProfile = true),
      audioService: _audioService,
    );
  }
}
