import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/echo_read/echo_read_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/phrase.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

class _FakeContentService extends ContentService {
  const _FakeContentService({this.withPhrases = true});

  final bool withPhrases;

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'i', type: 'pictograph', syllable: 'I', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'see', type: 'pictograph', syllable: 'see', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
        ],
        words: [],
      );

  @override
  Future<PhraseSet> loadPhrases() async => PhraseSet(
        version: '0',
        phrases: withPhrases
            ? const [
                Phrase(id: 'i_see_cat', tokens: ['i', 'see', 'cat'], blank: 2),
              ]
            : const [],
      );
}

class _RecordingAudioService implements AudioService {
  final List<String> speaks = [];

  @override
  Future<void> speak(String text) async => speaks.add(text);

  @override
  Future<void> stop() async {}
}

Future<void> _tapToken(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('er-token-$index')));
  await tester.pump();
}

void main() {
  testWidgets('tapping tokens left-to-right reads the whole phrase',
      (tester) async {
    final audio = _RecordingAudioService();
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: EchoReadPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // The named instruction was spoken on load.
    expect(audio.speaks, contains('Read with me! Tap each one.'));

    // Each tapped token speaks its syllable, in reading order.
    await _tapToken(tester, 0);
    expect(audio.speaks, contains('I'));
    expect(find.byKey(const Key('er-feedback')), findsNothing);

    await _tapToken(tester, 1);
    expect(audio.speaks, contains('see'));
    expect(find.byKey(const Key('er-feedback')), findsNothing);

    await _tapToken(tester, 2);
    expect(audio.speaks, contains('cat'));

    // The last tap completes the round: celebration + fluent full sentence
    // capped with spoken praise.
    expect(find.byKey(const Key('er-feedback')), findsOneWidget);
    expect(audio.speaks, contains('I see cat. You read it!'));

    // Exactly one correct learning event, about the phrase's answer token.
    expect(events, hasLength(1));
    expect(events.single.itemId, 'cat');
    expect(events.single.skill, 'read');
    expect(events.single.correct, isTrue);
    expect(events.single.game, 'echo_read');
  });

  testWidgets('an out-of-order tap speaks the token but does not advance',
      (tester) async {
    final audio = _RecordingAudioService();
    await tester.pumpWidget(MaterialApp(
      home: EchoReadPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
      ),
    ));
    await tester.pumpAndSettle();

    // Tap the last token first: tap-to-hear speaks it, nothing advances.
    await _tapToken(tester, 2);
    expect(audio.speaks, contains('cat'));
    expect(find.byKey(const Key('er-feedback')), findsNothing);

    // The expected token is still the first one — order must be respected.
    await _tapToken(tester, 1);
    expect(find.byKey(const Key('er-feedback')), findsNothing);

    // Completing in proper order still works (no way to fail).
    await _tapToken(tester, 0);
    await _tapToken(tester, 1);
    await _tapToken(tester, 2);
    expect(find.byKey(const Key('er-feedback')), findsOneWidget);
  });

  testWidgets('with no usable phrase a synthesized picture row is readable',
      (tester) async {
    final audio = _RecordingAudioService();
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: EchoReadPage(
        contentService: const _FakeContentService(withPhrases: false),
        audioService: audio,
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // A row of at least 3 distinct picturable tokens was synthesized.
    expect(find.byKey(const Key('er-token-0')), findsOneWidget);
    expect(find.byKey(const Key('er-token-2')), findsOneWidget);

    // It can be completed by tapping left to right.
    for (var i = 0; i < 4; i++) {
      final token = find.byKey(Key('er-token-$i'));
      if (token.evaluate().isEmpty) break;
      await tester.tap(token);
      await tester.pump();
    }
    expect(find.byKey(const Key('er-feedback')), findsOneWidget);
    expect(events, hasLength(1));
    expect(events.single.correct, isTrue);
  });

  testWidgets('singleRound auto-reports a flawless round and hides the arrow',
      (tester) async {
    final audio = _RecordingAudioService();
    final completions = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: EchoReadPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();

    // A lesson step has no manual "next" arrow.
    expect(find.byKey(const Key('er-next')), findsNothing);

    await _tapToken(tester, 0);
    await _tapToken(tester, 1);
    await _tapToken(tester, 2);
    expect(completions, isEmpty); // celebration first, then auto-advance

    await tester.pump(SingleRoundFlow.advanceDelay);
    expect(completions, [true]);
    expect(find.byKey(const Key('er-next')), findsNothing);
  });
}
