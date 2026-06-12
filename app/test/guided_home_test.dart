import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/home/guided_home_screen.dart';
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
  CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat', 'dog'], games: ['find_the_character'], xpToAdvance: 100),
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

void main() {
  testWidgets('Play runs one continuous level: intros chained, then a game',
      (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    await tester.pumpWidget(_home(progress));
    await tester.pumpAndSettle();

    // Enter the level — meet cat, then dog, without returning home in between.
    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);

    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('cat'), isTrue);
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget); // still inside

    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('dog'), isTrue);

    // Both met → the game is now playing, still inside the same session.
    expect(find.byKey(const Key('fc-prompt')), findsOneWidget);
  });

  testWidgets('leaving a level discards the session progress', (tester) async {
    final progress = ProgressService(bank: _bank, schedule: _schedule);
    await tester.pumpWidget(_home(progress));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro-done'))); // meet cat
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('cat'), isTrue);

    // Exit → confirm Leave → discards.
    await tester.tap(find.byKey(const Key('session-exit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-leave')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-play')), findsOneWidget); // back home
    expect(progress.hasSeenIntro('cat'), isFalse); // session was discarded
  });
}
