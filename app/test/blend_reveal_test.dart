import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/blend_reveal/blend_reveal_page.dart';
import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

class _FakeContentService extends ContentService {
  const _FakeContentService();

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'o', type: 'letter_array', syllable: 'O', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'pen', type: 'pictograph', syllable: 'pen', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'can', type: 'pictograph', syllable: 'can', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'dy', type: 'letter_array', syllable: 'dy', soundIpa: '', picturable: false),
        ],
        words: [
          Word(id: 'open', text: 'open', segmentation: ['o', 'pen']),
          Word(id: 'candy', text: 'candy', segmentation: ['can', 'dy']),
        ],
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
  Future<void> pumpGame(WidgetTester tester, BlendRevealPage page) async {
    await tester.pumpWidget(MaterialApp(home: page));
    await tester.pump(); // let the content future resolve → the round starts
  }

  testWidgets('sounds out the pieces then the word as the cards slide together',
      (tester) async {
    final audio = _FakeAudioService();

    await pumpGame(
      tester,
      BlendRevealPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        focusId: 'open', // deterministic first-round target
      ),
    );

    // Both syllable cards are on screen from the start of the reveal.
    expect(find.byKey(const Key('br-piece-0')), findsOneWidget);
    expect(find.byKey(const Key('br-piece-1')), findsOneWidget);

    // t=0: the instruction, then the first syllable.
    expect(audio.spoken, ['Watch the pieces make a word!', 'O']);

    // t≈700ms: the second syllable.
    await tester.pump(const Duration(milliseconds: 700));
    expect(audio.spoken.last, 'pen');

    // t≈1500ms: the whole word — the full sound-out arrives in order.
    await tester.pump(const Duration(milliseconds: 900));
    expect(audio.spoken, ['Watch the pieces make a word!', 'O', 'pen', 'open']);

    // The slide runs once, so the page settles cleanly.
    await tester.pumpAndSettle();
  });

  testWidgets('after the reveal, picking the made word solves the round',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await pumpGame(
      tester,
      BlendRevealPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        focusId: 'open',
        onEvent: events.add,
      ),
    );

    // Taps are ignored while the pieces are still sliding.
    await tester.tap(find.byKey(const Key('br-option-open')));
    await tester.pump();
    expect(events, isEmpty);
    expect(find.byKey(const Key('br-feedback')), findsNothing);

    // Let the animation (and the audio timers) finish.
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('br-option-open')));
    await tester.pump();

    expect(find.byKey(const Key('br-feedback')), findsOneWidget);
    expect(events, hasLength(1));
    expect(events.single.correct, isTrue);
    expect(events.single.itemId, 'open');
    expect(events.single.skill, 'blend');
    expect(events.single.stage, 2);
    expect(events.single.game, 'blend_reveal');
    // The solved word is named aloud, with praise.
    expect(audio.spoken.last, 'You got it! open!');
    // Standalone mode keeps the big next arrow.
    expect(find.byKey(const Key('br-next')), findsOneWidget);
  });

  testWidgets('singleRound: wrong then right reports a non-flawless completion',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];
    final completions = <bool>[];

    await pumpGame(
      tester,
      BlendRevealPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        focusId: 'open',
        onEvent: events.add,
        singleRound: true,
        onRoundComplete: ({required bool flawless}) => completions.add(flawless),
      ),
    );

    // Lesson steps auto-advance — no next arrow.
    expect(find.byKey(const Key('br-next')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pumpAndSettle();

    // Wrong pick: error feedback, a correct:false event, and the child hears
    // what the picked option actually says.
    await tester.tap(find.byKey(const Key('br-option-candy')));
    await tester.pump();
    expect(find.byKey(const Key('br-wrong')), findsOneWidget);
    expect(events.last.correct, isFalse);
    expect(audio.spoken.last, 'Oops! That says candy.');

    // Then the right one: solved, and after the celebration delay the lesson
    // hears that the round was not flawless.
    await tester.tap(find.byKey(const Key('br-option-open')));
    await tester.pump();
    expect(find.byKey(const Key('br-feedback')), findsOneWidget);
    expect(completions, isEmpty); // not before the celebration delay

    await tester.pump(SingleRoundFlow.advanceDelay);
    expect(completions, [false]);
  });
}
