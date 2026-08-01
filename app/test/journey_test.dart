import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/home/guided_home_screen.dart';
import 'package:reading_game/features/home/lesson_path_screen.dart';
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

const _schedule = CurriculumSchedule(
  version: '0',
  units: [
    CurriculumUnit(id: 1, title: 'Meadow', emoji: '🏡', levels: [1, 2]),
    CurriculumUnit(id: 2, title: 'Farm', emoji: '🌾', levels: [3]),
  ],
  levels: [
    CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat', 'dog'], games: ['find_the_character'], xpToAdvance: 100, lessons: 1),
    CurriculumLevel(id: 2, stage: 1, title: 'B', introduce: [], games: ['find_the_character'], xpToAdvance: 100, lessons: 1),
    CurriculumLevel(id: 3, stage: 1, title: 'C', introduce: [], games: ['find_the_character'], xpToAdvance: 100, lessons: 1),
  ],
);

class _FakeContent extends ContentService {
  const _FakeContent();
  @override
  Future<ContentBank> load() async => _bank;
}

class _FakeAudio implements AudioService {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

Widget _home(ProgressService progress, _FakeAudio audio) => MaterialApp(
      home: GuidedHomeScreen(
        progress: progress,
        engine: CurriculumEngine(schedule: _schedule, bank: _bank),
        schedule: _schedule,
        contentService: const _FakeContent(),
        audioService: audio,
      ),
    );

/// Solves the current Find-the-Character round by trying both options, then
/// rides out the auto-advance timers.
Future<void> _solveRound(WidgetTester tester) async {
  if (find.byKey(const Key('fc-option-cat')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('fc-option-cat')));
    await tester.pumpAndSettle();
    if (find.byKey(const Key('fc-feedback')).evaluate().isEmpty) {
      await tester.tap(find.byKey(const Key('fc-option-dog')));
      await tester.pumpAndSettle();
    }
  }
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pumpAndSettle();
}

/// Plays through a whole lesson to its celebration and continues out of it.
Future<void> _finishLesson(WidgetTester tester) async {
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
  await tester.tap(find.byKey(const Key('celebrate-continue')));
  await tester.pumpAndSettle();
  if (find.byKey(const Key('levelup-continue')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const Key('levelup-continue')));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(() => WorldScenery.animate = false);
  tearDown(() => WorldScenery.animate = true);

  testWidgets('gates open worlds, doors open rooms, nodes start lessons',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    final audio = _FakeAudio();
    await tester.pumpWidget(_home(progress, audio));
    await tester.pumpAndSettle();

    // A locked world answers aloud instead of opening.
    await tester.tap(find.byKey(const Key('world-2')));
    await tester.pumpAndSettle();
    expect(audio.spoken.last, contains('Locked'));
    expect(find.byKey(const Key('room-3')), findsNothing);

    // The current world's gate opens its rooms.
    await tester.tap(find.byKey(const Key('world-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('room-1')), findsOneWidget);
    expect(find.byKey(const Key('room-2')), findsOneWidget);

    // The current room's door opens its lesson path.
    await tester.tap(find.byKey(const Key('room-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('path-node-0')), findsOneWidget);

    // The glowing node starts the lesson (a meet lesson: intro first).
    await tester.tap(find.byKey(const Key('path-node-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);
  });

  testWidgets('replaying a beaten room celebrates but never moves the ladder',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    progress.markIntroSeen('cat');
    progress.markIntroSeen('dog');
    progress.completeLesson(); // beat level 1 → now at level 2
    expect(progress.level, 2);

    final audio = _FakeAudio();
    await tester.pumpWidget(MaterialApp(
      home: LessonPathScreen(
        levelId: 1,
        progress: progress,
        engine: CurriculumEngine(schedule: _schedule, bank: _bank),
        schedule: _schedule,
        contentService: const _FakeContent(),
        audioService: audio,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('path-node-0')));
    await tester.pumpAndSettle();
    await _finishLesson(tester);

    expect(progress.level, 2); // unmoved
    expect(progress.lessonsIntoLevel, 0);
  });
}
