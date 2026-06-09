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

class _FakeContent extends ContentService {
  const _FakeContent();
  @override
  Future<ContentBank> load() async => _bank;
}

class _FakeAudio implements AudioService {
  @override
  Future<void> speak(String text) async {}
}

void main() {
  testWidgets('Play introduces each new symbol before launching a game',
      (tester) async {
    const schedule = CurriculumSchedule(version: '0', levels: [
      CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat', 'dog'], games: ['find_the_character'], xpToAdvance: 100),
    ]);
    final progress = ProgressService(bank: _bank, schedule: schedule);
    final engine = CurriculumEngine(schedule: schedule, bank: _bank);

    await tester.pumpWidget(MaterialApp(
      home: GuidedHomeScreen(
        progress: progress,
        engine: engine,
        schedule: schedule,
        contentService: const _FakeContent(),
        audioService: _FakeAudio(),
      ),
    ));
    await tester.pumpAndSettle();

    // First Play → meet 'cat'.
    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('cat'), isTrue);

    // Second Play → meet 'dog'.
    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('intro-symbol')), findsOneWidget);
    await tester.tap(find.byKey(const Key('intro-done')));
    await tester.pumpAndSettle();
    expect(progress.hasSeenIntro('dog'), isTrue);

    // Third Play → both symbols met, so now a game launches.
    await tester.tap(find.byKey(const Key('home-play')));
    await tester.pumpAndSettle();
    expect(find.text('Find the Character'), findsOneWidget);
  });
}
