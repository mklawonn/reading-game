import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/symbol_hunt/symbol_hunt_page.dart';
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
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'bee', type: 'pictograph', syllable: 'bee', soundIpa: '', picturable: true),
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

/// The round names its task aloud ("Find all the suns!"); derive the target
/// element id from it (the fake bank uses id == syllable).
String _targetFromInstruction(String said) {
  expect(said, startsWith('Find all the '));
  expect(said, endsWith('s!'));
  return said.substring('Find all the '.length, said.length - 2);
}

/// A tall test surface so every grid cell is on-screen and tappable.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('speaks the hunt instruction and finding every copy completes '
      'the round with one correct event', (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: SymbolHuntPage(
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
        tester.state<SymbolHuntPageState>(find.byType(SymbolHuntPage));
    final ids = state.cellIds;
    expect(ids, hasLength(6));
    final targetIndices = [
      for (var i = 0; i < ids.length; i++)
        if (ids[i] == target) i
    ];
    expect(targetIndices.length, inInclusiveRange(2, 3));

    // Tap every copy of the target — the round completes on the last one.
    for (final i in targetIndices) {
      await tester.tap(find.byKey(Key('sh-cell-$i')));
      await tester.pump();
    }

    expect(find.byKey(const Key('sh-feedback')), findsOneWidget);
    expect(events, hasLength(1));
    expect(events.single.correct, isTrue);
    expect(events.single.itemId, target);
    expect(events.single.skill, 'recognize');
    expect(events.single.game, 'symbol_hunt');
  });

  testWidgets('a wrong tap names the tapped symbol and only the first one '
      'emits a correct:false event', (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: SymbolHuntPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(2),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    final target = _targetFromInstruction(audio.spoken.last);
    final state =
        tester.state<SymbolHuntPageState>(find.byType(SymbolHuntPage));
    final ids = state.cellIds;
    final wrongIndex = ids.indexWhere((id) => id != target);

    await tester.tap(find.byKey(Key('sh-cell-$wrongIndex')));
    await tester.pump();

    expect(find.byKey(const Key('sh-wrong')), findsOneWidget);
    // A distinct miss that names what they actually tapped, not the target.
    expect(audio.spoken.last, 'Oops! That is the ${ids[wrongIndex]}.');
    expect(events.where((e) => !e.correct), hasLength(1));

    // A second wrong tap must not emit another demotion.
    await tester.tap(find.byKey(Key('sh-cell-$wrongIndex')));
    await tester.pump();

    expect(events.where((e) => !e.correct), hasLength(1));
    expect(events.where((e) => e.correct), isEmpty);
  });

  testWidgets('singleRound auto-advances with flawless:false after a wrong tap '
      'and shows no next arrow', (tester) async {
    _useTallSurface(tester);
    final audio = _FakeAudioService();
    final completions = <bool>[];

    await tester.pumpWidget(MaterialApp(
      home: SymbolHuntPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sh-next')), findsNothing);

    final target = _targetFromInstruction(audio.spoken.last);
    final state =
        tester.state<SymbolHuntPageState>(find.byType(SymbolHuntPage));
    final ids = state.cellIds;

    // One wrong tap first, then find every copy of the target.
    final wrongIndex = ids.indexWhere((id) => id != target);
    await tester.tap(find.byKey(Key('sh-cell-$wrongIndex')));
    await tester.pump();
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] == target) {
        await tester.tap(find.byKey(Key('sh-cell-$i')));
        await tester.pump();
      }
    }

    expect(find.byKey(const Key('sh-feedback')), findsOneWidget);
    // The celebration lingers before the lesson advances.
    expect(completions, isEmpty);
    await tester.pump(SingleRoundFlow.advanceDelay);
    expect(completions, [false]);
    expect(find.byKey(const Key('sh-next')), findsNothing);
  });
}
