import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/rebus_quest/rebus_quest_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

SyllableElement _el(String id, {bool picturable = true}) => SyllableElement(
    id: id, type: 'pictograph', syllable: id, soundIpa: '',
    picturable: picturable);

class _FakeContentService extends ContentService {
  const _FakeContentService();

  @override
  Future<ContentBank> load() async => ContentBank(
        version: '0',
        elements: [
          _el('cat'), _el('fish'), _el('sun'),
          _el('house'), _el('box'), _el('bed'),
          _el('see', picturable: false),
          _el('the', picturable: false),
          _el('in', picturable: false),
        ],
        words: const [],
      );
}

class _FakeAudioService implements AudioService {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets('the sentence is the instruction: reading it finds the pair',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: RebusQuestPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // Generic instruction only — the narrator must NEVER read the sentence.
    expect(audio.spoken.first, 'Read it! Who is hiding where?');

    final state =
        tester.state<RebusQuestPageState>(find.byType(RebusQuestPage));
    final targetHider = state.spotHiderIds[state.targetSpot];

    // Wrong spot: distinct miss naming what IS there, correct:false event.
    final wrongSpot =
        (state.targetSpot + 1) % state.spotHiderIds.length;
    final wrongContainerKey = find.byKey(Key(
        'rq-spot-${_containerIdAt(tester, wrongSpot)}'));
    await tester.tap(wrongContainerKey);
    await tester.pump();
    expect(find.byKey(const Key('rq-wrong')), findsOneWidget);
    expect(audio.spoken.last, startsWith('Oops! That is the '));
    expect(events.single.correct, isFalse);
    expect(events.single.game, 'rebus_quest');

    // Right spot: reveal + the full sentence as the spoken reward.
    await tester
        .tap(find.byKey(Key('rq-spot-${_containerIdAt(tester, state.targetSpot)}')));
    await tester.pump();
    expect(find.byKey(const Key('rq-feedback')), findsOneWidget);
    expect(audio.spoken.last, contains('The $targetHider is in the '));
    expect(events.last.correct, isTrue);
    expect(events.last.itemId, targetHider);
  });

  testWidgets('singleRound: no next arrow; completion reports flawless flag',
      (tester) async {
    final audio = _FakeAudioService();
    final completions = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: RebusQuestPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(5),
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rq-next')), findsNothing);

    final state =
        tester.state<RebusQuestPageState>(find.byType(RebusQuestPage));
    await tester.tap(find.byKey(
        Key('rq-spot-${_containerIdAt(tester, state.targetSpot)}')));
    await tester.pump();
    expect(completions, isEmpty);
    await tester.pump(SingleRoundFlow.advanceDelay);
    expect(completions, [true]);
  });

  testWidgets('unplayable pools self-skip in singleRound', (tester) async {
    final completions = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: RebusQuestPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudioService(),
        random: Random(1),
        allowedIds: const {'cat', 'house'}, // one hider, one container
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Not enough to play yet.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(completions, [true]);
  });
}

/// The container element id shown at spot [index] (keys are per-container).
String _containerIdAt(WidgetTester tester, int index) {
  final state =
      tester.state<RebusQuestPageState>(find.byType(RebusQuestPage));
  // Keys are 'rq-spot-<containerId>'; recover the container by walking the
  // spot list through the state's public test surface.
  return state.containerIdAt(index);
}
