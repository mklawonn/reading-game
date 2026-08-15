import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/home/guided_home_screen.dart';
import 'package:reading_game/features/home/world_scenery.dart';
import 'package:reading_game/learning/curriculum_engine.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/curriculum.dart';
import 'package:reading_game/progress/progress_service.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

const _bank = ContentBank(
  version: '0',
  elements: [
    SyllableElement(id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
    SyllableElement(id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
  ],
  words: [],
);

const _schedule = CurriculumSchedule(version: '0', levels: [
  CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat', 'dog'], games: ['find_the_character'], xpToAdvance: 100, lessons: 1),
  CurriculumLevel(id: 2, stage: 1, title: 'B', introduce: [], games: ['find_the_character'], xpToAdvance: 100, lessons: 1),
]);

class _FakeContent extends ContentService {
  const _FakeContent();
  @override
  Future<ContentBank> load() async => _bank;
}

class _FakeAudio implements AudioService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

Widget _home(ProgressService progress) => MaterialApp(
      home: GuidedHomeScreen(
        progress: progress,
        engine: CurriculumEngine(schedule: _schedule, bank: _bank),
        schedule: _schedule,
        contentService: const _FakeContent(),
        audioService: _FakeAudio(),
      ),
    );

/// Solves the current Find-the-Character round by trying both options; if no
/// round is on screen (e.g. the pre-celebration beat), just lets time pass.
Future<void> _solveRound(WidgetTester tester) async {
  if (find.byKey(const Key('fc-option-cat')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('fc-option-cat')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('fc-feedback')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('fc-option-dog')));
      await tester.pumpAndSettle();
    }
  }
  // Let the auto-advance (and the pre-celebration beat) timers fire.
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => WorldScenery.animate = false); // let screens settle in tests
  tearDown(() => WorldScenery.animate = true);

  testWidgets('a lesson interleaves intros with focused exercises',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    await tester.pumpWidget(_home(progress));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();

    // Meet cat…
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('cat'), isTrue);

    // …then immediately practice it: the exercise is focused on cat.
    expect(find.byKey(const Key('fc-prompt')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fc-option-cat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fc-feedback')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    // Next up: meet dog.
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('dog'), isTrue);
  });

  testWidgets('finishing a lesson celebrates, levels up, and returns home',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    await tester.pumpWidget(_home(progress));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();

    // Play through every step (intros + exercises + possible re-queues).
    for (var i = 0; i < 40; i++) {
      if (find.byKey(const Key('celebrate-continue')).evaluate().isNotEmpty) {
        break;
      }
      if (find.byKey(const Key('intro-done')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('intro-done')));
        await tester.pumpAndSettle();
      } else {
        await _solveRound(tester);
      }
    }

    // The finish line: stars + continue.
    expect(find.byKey(const Key('celebrate-continue')), findsOneWidget);
    expect(find.byKey(const Key('celebrate-star-0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('celebrate-continue')));
    await tester.pumpAndSettle();

    // One lesson beats level 1 → the level-up overlay…
    expect(find.byKey(const Key('levelup-continue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('levelup-continue')));
    await tester.pumpAndSettle();

    // …then the lesson path shows the marker's hop and the room-finished
    // beat before walking itself back out to the street.
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-play')), findsOneWidget);
    expect(progress.level, 2);
  });

  testWidgets('leaving a lesson keeps progress — it is never punished',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    await tester.pumpWidget(_home(progress));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro-done'))); // meet cat
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('cat'), isTrue);

    // Exit → confirm leave (icon dialog).
    await tester.tap(find.byKey(const Key('session-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-leave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-play')), findsOneWidget); // back home
    expect(progress.hasSeenIntro('cat'), isTrue); // met symbols stay met
    expect(progress.lessonsIntoLevel, 0); // but the lesson didn't count
  });
}
