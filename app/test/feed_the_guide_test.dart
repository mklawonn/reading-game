import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/guide_character.dart';
import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/feed_the_guide/feed_the_guide_page.dart';
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
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'hat', type: 'pictograph', syllable: 'hat', soundIpa: '', picturable: true),
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

/// The element id the guide last asked for (`"<Name> wants the <id>!"` — the
/// fakes use id == syllable, mirroring listen_and_pick's test).
String _requestedId(List<String> spoken) {
  final said = spoken.lastWhere((s) => s.contains(' wants the '));
  const marker = ' wants the ';
  final start = said.indexOf(marker) + marker.length;
  return said.substring(start, said.length - 1); // strip the "!"
}

Future<void> _dragOnto(WidgetTester tester, Finder from, Finder to) async {
  final gesture = await tester.startGesture(tester.getCenter(from));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.moveTo(tester.getCenter(to));
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'first request honors focusId; a correct tap feeds the guide and '
      'chains the next request', (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: FeedTheGuidePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        guide: const Guide('🐻', 'Bo'),
        requestCount: 2,
        random: Random(1),
        focusId: 'sun',
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // The guide asks for the focus element by name.
    expect(audio.spoken.last, 'Bo wants the sun!');
    expect(find.byKey(const Key('fg-plates')), findsOneWidget);

    // Giving the right card feeds the guide.
    await tester.tap(find.byKey(const Key('fg-option-sun')));
    await tester.pump();
    expect(audio.spoken, contains('Yum! sun!'));
    expect(events.single.correct, isTrue);
    expect(events.single.itemId, 'sun');
    expect(events.single.skill, 'recognize');
    expect(events.single.game, 'feed_the_guide');

    // After the "Yum!" resolves (microtasks), the SECOND request is voiced —
    // and it never repeats the previous target.
    await tester.pump();
    await tester.pump();
    final second = audio.spoken.last;
    expect(second, startsWith('Bo wants the '));
    expect(second, isNot('Bo wants the sun!'));

    await tester.pumpAndSettle(); // flush the munch reaction timer
  });

  testWidgets('a wrong tap records an error, speaks a gentle miss, and the '
      'round is still completable', (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: FeedTheGuidePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        requestCount: 2,
        random: Random(1),
        focusId: 'sun',
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();
    expect(audio.spoken.last, 'Fern wants the sun!');

    // Give the wrong card: sad feedback, a correct:false event for the
    // CURRENT target, and the miss names what was touched.
    await tester.tap(find.byKey(const Key('fg-option-bee')));
    await tester.pump();
    expect(find.byKey(const Key('fg-wrong')), findsOneWidget);
    expect(events.single.correct, isFalse);
    expect(events.single.itemId, 'sun');
    expect(audio.spoken.last, 'Oops! That is the bee.');

    // The round is still completable: feed both requests.
    await tester.tap(find.byKey(const Key('fg-option-sun')));
    await tester.pumpAndSettle();
    final secondTarget = _requestedId(audio.spoken);
    expect(secondTarget, isNot('sun'));
    await tester.tap(find.byKey(Key('fg-option-$secondTarget')));
    await tester.pump();
    expect(find.byKey(const Key('fg-feedback')), findsOneWidget);
    expect(events.where((e) => e.correct).length, 2);

    await tester.pumpAndSettle();
  });

  testWidgets('completing all requests fills the guide; singleRound '
      'auto-advances with the flawless flag and shows no next arrow',
      (tester) async {
    final audio = _FakeAudioService();
    bool? flawlessResult;

    await tester.pumpWidget(MaterialApp(
      home: FeedTheGuidePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        requestCount: 2,
        random: Random(1),
        focusId: 'sun',
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            flawlessResult = flawless,
      ),
    ));
    await tester.pumpAndSettle();

    // Feed request 1, then request 2.
    await tester.tap(find.byKey(const Key('fg-option-sun')));
    await tester.pumpAndSettle();
    final secondTarget = _requestedId(audio.spoken);
    await tester.tap(find.byKey(Key('fg-option-$secondTarget')));
    await tester.pump();

    // The guide is full: celebration shown, closing line captured, and the
    // lesson-step contract holds (no next arrow, advance only after delay).
    expect(find.byKey(const Key('fg-feedback')), findsOneWidget);
    expect(find.byKey(const Key('fg-next')), findsNothing);
    expect(audio.spoken.last,
        'Yum! $secondTarget! Fern is full — thank you!');
    expect(flawlessResult, isNull);

    await tester.pump(SingleRoundFlow.advanceDelay);
    await tester.pump();
    await tester.pump();
    expect(flawlessResult, isTrue);

    await tester.pumpAndSettle();
  });

  testWidgets('dragging a card onto the guide gives it, same as tapping',
      (tester) async {
    final audio = _FakeAudioService();
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: FeedTheGuidePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        requestCount: 2,
        random: Random(1),
        focusId: 'sun',
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    await _dragOnto(
      tester,
      find.byKey(const Key('fg-option-sun')),
      find.byKey(const Key('fg-guide')),
    );

    expect(audio.spoken, contains('Yum! sun!'));
    final fed = events.where((e) => e.correct && e.itemId == 'sun');
    expect(fed, hasLength(1));

    await tester.pumpAndSettle();
  });
}
