import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/hidden_glyph/hidden_glyph_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

/// Five picturable elements, including the confusable pair dog+pup — a
/// pup-target board must never seat a dog.
class _FakeContentService extends ContentService {
  const _FakeContentService();

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'bee', type: 'pictograph', syllable: 'bee', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'pup', type: 'pictograph', syllable: 'pup', soundIpa: '', picturable: true),
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

/// The round names its task aloud ("Look everywhere! Find the sun!"); derive
/// the target element id from it (the fake bank uses id == syllable).
String _targetFromInstruction(String said) {
  expect(said, startsWith('Look everywhere! Find the '));
  expect(said, endsWith('!'));
  return said.substring('Look everywhere! Find the '.length, said.length - 1);
}

/// A tall test surface so every scattered glyph is on-screen and tappable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('speaks the search instruction, hides exactly 2 copies, and '
      'finding both completes the round with one correct event',
      (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: HiddenGlyphPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    expect(audio.spoken, isNotEmpty);
    final target = _targetFromInstruction(audio.spoken.last);

    final state =
        tester.state<HiddenGlyphPageState>(find.byType(HiddenGlyphPage));
    final ids = state.glyphIds;
    expect(ids.length, greaterThanOrEqualTo(10));
    final targetIndices = [
      for (var i = 0; i < ids.length; i++)
        if (ids[i] == target) i
    ];
    expect(targetIndices, hasLength(2));

    // Tap both hidden copies — the round completes on the second one.
    await tester.tap(find.byKey(Key('hg-glyph-${targetIndices.first}')));
    await tester.pump();
    expect(audio.spoken.last, target); // first find names the word
    await tester.tap(find.byKey(Key('hg-glyph-${targetIndices.last}')));
    await tester.pump();

    expect(find.byKey(const Key('hg-feedback')), findsOneWidget);
    // The final pop speaks the completion line INSTEAD of the bare word.
    expect(audio.spoken.last, '$target! You found them!');
    expect(events, hasLength(1));
    expect(events.single.correct, isTrue);
    expect(events.single.itemId, target);
    expect(events.single.skill, 'recognize');
    expect(events.single.game, 'hidden_glyph');
  });

  testWidgets('a wrong tap names the tapped symbol and only the first one '
      'emits a correct:false event', (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: HiddenGlyphPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(2),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    final target = _targetFromInstruction(audio.spoken.last);
    final state =
        tester.state<HiddenGlyphPageState>(find.byType(HiddenGlyphPage));
    final ids = state.glyphIds;
    final wrongIndex = ids.indexWhere((id) => id != target);

    await tester.tap(find.byKey(Key('hg-glyph-$wrongIndex')));
    await tester.pump();

    expect(find.byKey(const Key('hg-wrong')), findsOneWidget);
    // A distinct miss that names what they actually tapped, not the target.
    expect(audio.spoken.last, 'Oops! That is the ${ids[wrongIndex]}.');
    expect(events.where((e) => !e.correct), hasLength(1));

    // A second wrong tap must not emit another demotion.
    await tester.tap(find.byKey(Key('hg-glyph-$wrongIndex')));
    await tester.pump();

    expect(events.where((e) => !e.correct), hasLength(1));
    expect(events.where((e) => e.correct), isEmpty);
  });

  testWidgets('a pup-target board never seats a dog (look-alike guard)',
      (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: HiddenGlyphPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        focusId: 'pup',
      ),
    ));
    await tester.pumpAndSettle();

    expect(audio.spoken.last, 'Look everywhere! Find the pup!');
    final state =
        tester.state<HiddenGlyphPageState>(find.byType(HiddenGlyphPage));
    final ids = state.glyphIds;
    expect(ids.where((id) => id == 'pup'), hasLength(2));
    // The confusable look-alike must be filtered out of the decoys.
    expect(ids, isNot(contains('dog')));
  });

  testWidgets('singleRound auto-advances with flawless:false after a wrong tap '
      'and shows no next arrow', (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final completions = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: HiddenGlyphPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(4),
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hg-next')), findsNothing);

    final target = _targetFromInstruction(audio.spoken.last);
    final state =
        tester.state<HiddenGlyphPageState>(find.byType(HiddenGlyphPage));
    final ids = state.glyphIds;

    // One wrong tap first, then find both hidden copies of the target.
    final wrongIndex = ids.indexWhere((id) => id != target);
    await tester.tap(find.byKey(Key('hg-glyph-$wrongIndex')));
    await tester.pump();
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] == target) {
        await tester.tap(find.byKey(Key('hg-glyph-$i')));
        await tester.pump();
      }
    }

    expect(find.byKey(const Key('hg-feedback')), findsOneWidget);
    // The celebration lingers before the lesson advances.
    expect(completions, isEmpty);
    await tester.pump(SingleRoundFlow.advanceDelay);
    expect(completions, [false]);
    expect(find.byKey(const Key('hg-next')), findsNothing);
  });
}
