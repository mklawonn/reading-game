import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/picture_to_word/picture_to_word_page.dart';
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
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
        ],
        words: [],
      );
}

class _FakeAudioService implements AudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

const _ids = ['cat', 'dog', 'sun'];

/// The round names its target aloud ("Which word says cat?") — derive the
/// target id from that instruction, like listen_and_pick_test does.
String _targetFrom(List<String> spoken) {
  final said = spoken.lastWhere((s) => s.startsWith('Which word says '));
  return said.substring('Which word says '.length, said.length - 1);
}

void main() {
  testWidgets('speaks the instruction and accepts the matching written word',
      (tester) async {
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: PictureToWordPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
      ),
    ));
    await tester.pumpAndSettle();

    // The instruction is spoken on load and names the target.
    expect(audio.spoken, isNotEmpty);
    expect(audio.spoken.last, startsWith('Which word says '));
    final target = _targetFrom(audio.spoken);
    expect(_ids, contains(target));

    // Tapping the written word that matches the picture solves the round.
    await tester.tap(find.byKey(Key('pw-option-$target')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pw-feedback')), findsOneWidget);
  });

  testWidgets('wrong pick shows feedback and emits correct:false, then recovers',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: PictureToWordPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    final target = _targetFrom(audio.spoken);
    final wrong = _ids.firstWhere((id) => id != target);

    await tester.tap(find.byKey(Key('pw-option-$wrong')));
    await tester.pumpAndSettle();

    // Not solved: error feedback shows, and the miss was recorded.
    expect(find.byKey(const Key('pw-wrong')), findsOneWidget);
    expect(find.byKey(const Key('pw-feedback')), findsNothing);
    expect(events, hasLength(1));
    expect(events.last.correct, isFalse);
    expect(events.last.itemId, target);
    expect(events.last.game, 'picture_to_word');
    // The child hears — distinctly as a miss — what the picked word says.
    expect(audio.spoken.last, 'Oops! That word says $wrong.');

    // The correct tap still solves the round and emits correct:true.
    await tester.tap(find.byKey(Key('pw-option-$target')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pw-feedback')), findsOneWidget);
    expect(events, hasLength(2));
    expect(events.last.correct, isTrue);
    expect(events.last.itemId, target);
  });

  testWidgets('singleRound: no next arrow; reports completion with flawless',
      (tester) async {
    final audio = _FakeAudioService();
    final completions = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: PictureToWordPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        singleRound: true,
        onRoundComplete: ({required bool flawless}) => completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();

    // A lesson step has no "next" arrow — it advances itself.
    expect(find.byKey(const Key('pw-next')), findsNothing);

    final target = _targetFrom(audio.spoken);
    final wrong = _ids.firstWhere((id) => id != target);

    // One miss first, so the round completes non-flawless.
    await tester.tap(find.byKey(Key('pw-option-$wrong')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('pw-option-$target')));
    await tester.pumpAndSettle();

    // The completion callback fires only after the celebration delay.
    expect(completions, isEmpty);
    await tester.pump(SingleRoundFlow.advanceDelay);

    expect(completions, [false]);
    expect(find.byKey(const Key('pw-next')), findsNothing);
  });
}
