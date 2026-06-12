import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/home/level_session_screen.dart';
import 'package:reading_game/learning/curriculum_engine.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/curriculum.dart';
import 'package:reading_game/progress/learning_event.dart';
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

class _FakeContent extends ContentService {
  const _FakeContent();
  @override
  Future<ContentBank> load() async => _bank;
}

class _FakeAudio implements AudioService {
  int stops = 0;
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {
    stops++;
  }
}

LearningEvent _correct() => const LearningEvent(
    itemId: 'cat', skill: 'recognize', stage: 1, correct: true, game: 'g');

/// Pushes the session from a launcher so popping it has somewhere to land.
Widget _harness(ProgressService progress, CurriculumSchedule schedule,
    _FakeAudio audio) {
  return MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('launch'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => LevelSessionScreen(
                progress: progress,
                engine: CurriculumEngine(schedule: schedule, bank: _bank),
                schedule: schedule,
                contentService: const _FakeContent(),
                audioService: audio,
              ),
            )),
            child: const Text('launch'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'crossing several level thresholds at once celebrates exactly once',
      (tester) async {
    // Tiny thresholds so one mastery-bonus grant (35 XP) can cross two levels.
    const schedule = CurriculumSchedule(version: '0', levels: [
      CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: [], games: ['find_the_character'], xpToAdvance: 40),
      CurriculumLevel(id: 2, stage: 1, title: 'B', introduce: ['dog'], games: ['find_the_character'], xpToAdvance: 15),
      CurriculumLevel(id: 3, stage: 1, title: 'C', introduce: [], games: ['find_the_character'], xpToAdvance: 100),
    ]);
    final progress = ProgressService(bank: _bank, schedule: schedule);
    final audio = _FakeAudio();

    await tester.pumpWidget(_harness(progress, schedule, audio));
    await tester.tap(find.byKey(const Key('launch')));
    await tester.pumpAndSettle();

    // 3 corrects = 30 XP (below the 40 goal), 4th = +35 (mastery bonus) → 65:
    // crosses level 1 → 2 → 3 in a single grant.
    for (var i = 0; i < 4; i++) {
      progress.record(_correct());
      await tester.pumpAndSettle();
    }
    expect(progress.level, 3);

    // ONE combined celebration — not a rapid-fire queue of dialogs.
    expect(find.byKey(const Key('levelup-continue')), findsOneWidget);
    expect(find.text('Level 3!'), findsOneWidget);

    await tester.tap(find.byKey(const Key('levelup-continue')));
    await tester.pumpAndSettle();

    // Session popped back to the launcher; nothing else queued.
    expect(find.byKey(const Key('launch')), findsOneWidget);
    expect(find.byKey(const Key('levelup-continue')), findsNothing);
    expect(progress.takeJustLeveledUp(), isEmpty);
  });

  testWidgets('leaving a session stops any in-flight audio', (tester) async {
    const schedule = CurriculumSchedule(version: '0', levels: [
      CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat'], games: ['find_the_character'], xpToAdvance: 40),
    ]);
    final progress = ProgressService(bank: _bank, schedule: schedule);
    final audio = _FakeAudio();

    await tester.pumpWidget(_harness(progress, schedule, audio));
    await tester.tap(find.byKey(const Key('launch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('session-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-leave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('launch')), findsOneWidget); // back out
    expect(audio.stops, greaterThan(0)); // TTS cut on dispose — no bleed
  });
}
