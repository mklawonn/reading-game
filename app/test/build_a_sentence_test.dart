import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/content/token_view.dart';
import 'package:reading_game/features/build_a_sentence/build_a_sentence_page.dart';
import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/phrase.dart';
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
              id: 'the', type: 'letter_array', syllable: 'the', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'is', type: 'letter_array', syllable: 'is', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'big', type: 'letter_array', syllable: 'big', soundIpa: '', picturable: false),
        ],
        words: [],
      );

  @override
  Future<PhraseSet> loadPhrases() async => const PhraseSet(
        version: '0',
        phrases: [
          Phrase(id: 'the_dog_is_big', tokens: ['the', 'dog', 'is', 'big'], blank: 1),
        ],
      );
}

/// No phrases at all, but four picturable elements — forces the synthesized
/// Gleitman & Rozin pictograph-row fallback.
class _NoPhrasesContentService extends ContentService {
  const _NoPhrasesContentService();

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'bed', type: 'pictograph', syllable: 'bed', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'key', type: 'pictograph', syllable: 'key', soundIpa: '', picturable: true),
        ],
        words: [],
      );

  @override
  Future<PhraseSet> loadPhrases() async =>
      const PhraseSet(version: '0', phrases: []);
}

class _FakeAudioService implements AudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

/// Pieces get their tokens in target-sequence order (0, 1, 2, ... then the
/// distractor), so tapping `bs-piece-0..n` in order always builds correctly.
Future<void> _tapPieces(WidgetTester tester, List<int> tokens) async {
  for (final t in tokens) {
    await tester.tap(find.byKey(Key('bs-piece-$t')));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
      'speaks instruction then sentence; tapping pieces in order solves',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: BuildASentencePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // The instruction is spoken first, then — chained — the full sentence.
    expect(audio.spoken.first, 'Listen! Build the sentence.');
    expect(audio.spoken, contains('the dog is big'));

    // Four slots for the four tokens; the sentence itself is never printed.
    expect(find.byKey(const Key('bs-slot-3')), findsOneWidget);
    expect(find.byKey(const Key('bs-next')), findsOneWidget);

    // Tap the pieces in target order → slots fill left-to-right and solve.
    await _tapPieces(tester, [0, 1, 2, 3]);

    expect(find.byKey(const Key('bs-feedback')), findsOneWidget);
    // Praise + the fluent sentence in one utterance.
    expect(audio.spoken.last, endsWith('the dog is big!'));
    expect(events.single.correct, isTrue);
    expect(events.single.game, 'build_a_sentence');
    expect(events.single.skill, 'read');
    expect(events.single.itemId, 'dog'); // the phrase's blank answer
  });

  testWidgets('a wrong order is recorded and can be fixed by taking pieces back',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: BuildASentencePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(7),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // Fill the board with the first two tokens swapped.
    await _tapPieces(tester, [1, 0, 2, 3]);

    expect(find.byKey(const Key('bs-wrong')), findsOneWidget);
    expect(find.byKey(const Key('bs-feedback')), findsNothing);
    expect(events, hasLength(1));
    expect(events.single.correct, isFalse);
    expect(
        audio.spoken.any((s) => s.startsWith('Not yet! Listen again:')), isTrue);

    // Tap the two misplaced slots to take the pieces back...
    await tester.tap(find.byKey(const Key('bs-slot-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bs-slot-1')));
    await tester.pumpAndSettle();
    // ...then reseat them the right way round.
    await _tapPieces(tester, [0, 1]);

    expect(find.byKey(const Key('bs-feedback')), findsOneWidget);
    expect(events, hasLength(2));
    expect(events.last.correct, isTrue);
  });

  testWidgets('no phrases → synthesized 3-token row including the focus element',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: BuildASentencePage(
        contentService: const _NoPhrasesContentService(),
        audioService: audio,
        random: Random(11),
        focusId: 'sun',
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // Exactly three slots — a synthesized pictograph row, not a phrase.
    expect(find.byKey(const Key('bs-slot-2')), findsOneWidget);
    expect(find.byKey(const Key('bs-slot-3')), findsNothing);

    // The focus element is among the pieces on the board.
    final tokenViews = tester.widgetList<TokenView>(find.byType(TokenView));
    expect(tokenViews.any((t) => t.element.id == 'sun'), isTrue);

    // The row can be solved by seating the sequence pieces in order.
    await _tapPieces(tester, [0, 1, 2]);
    expect(find.byKey(const Key('bs-feedback')), findsOneWidget);
    expect(events.single.correct, isTrue);
    expect(events.single.game, 'build_a_sentence');
  });

  testWidgets('singleRound hides the next arrow and reports the flawless flag',
      (tester) async {
    Future<void> run(
        {required bool makeMistake, required bool expected}) async {
      bool? reported;
      await tester.pumpWidget(MaterialApp(
        home: BuildASentencePage(
          // A fresh key per run — otherwise the second pumpWidget would update
          // the first run's (already solved) state instead of starting over.
          key: ValueKey('bs-run-mistake-$makeMistake'),
          contentService: const _FakeContentService(),
          audioService: _FakeAudioService(),
          random: Random(5),
          singleRound: true,
          onRoundComplete: ({required bool flawless}) => reported = flawless,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bs-next')), findsNothing);

      if (makeMistake) {
        await _tapPieces(tester, [1, 0, 2, 3]); // wrong build first
        await tester.tap(find.byKey(const Key('bs-slot-0')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bs-slot-1')));
        await tester.pumpAndSettle();
        await _tapPieces(tester, [0, 1]); // then fix it
      } else {
        await _tapPieces(tester, [0, 1, 2, 3]);
      }
      expect(find.byKey(const Key('bs-feedback')), findsOneWidget);
      // The celebration must play out before the round reports complete.
      expect(reported, isNull);

      await tester.pump(SingleRoundFlow.advanceDelay);
      await tester.pump();
      await tester.pump();
      expect(reported, expected);
    }

    await run(makeMistake: false, expected: true);
    await run(makeMistake: true, expected: false);
  });
}
