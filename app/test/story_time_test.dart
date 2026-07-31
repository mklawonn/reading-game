import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/common/single_round.dart';
import 'package:reading_game/features/story_time/story_time_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/story.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

class _FakeContentService extends ContentService {
  const _FakeContentService({this.withStories = true});

  final bool withStories;

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'cat',
              type: 'pictograph',
              syllable: 'cat',
              soundIpa: '',
              picturable: true),
          SyllableElement(
              id: 'the',
              type: 'glyph',
              syllable: 'the',
              soundIpa: '',
              picturable: false),
          SyllableElement(
              id: 'is',
              type: 'glyph',
              syllable: 'is',
              soundIpa: '',
              picturable: false),
          SyllableElement(
              id: 'big',
              type: 'pictograph',
              syllable: 'big',
              soundIpa: '',
              picturable: true),
        ],
        words: [],
      );

  @override
  Future<StorySet> loadStories() async => StorySet(
        version: '0',
        stories: withStories
            ? const [
                Story(
                  id: 'big_cat',
                  title: 'The Big Cat',
                  unlockLevel: 1,
                  lines: [
                    ['cat'],
                    ['the', 'cat', 'is', 'big'],
                  ],
                ),
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
  await tester.tap(find.byKey(Key('st-token-$index')));
  await tester.pump();
}

/// The line-advance chain is pure microtasks with completed fake speech
/// futures; a few zero-duration pumps flush it through.
Future<void> _flushSpeechChain(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets(
      'tapping line 1 speaks its tokens, reads the line back fluently, '
      'and advances to line 2', (tester) async {
    final audio = _RecordingAudioService();
    await tester.pumpWidget(MaterialApp(
      home: StoryTimePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
      ),
    ));
    await tester.pumpAndSettle();

    // The named instruction was spoken on load.
    expect(audio.speaks, contains('Story time! Tap along with me.'));

    // Line 1 has exactly one token; the dot row is present.
    expect(find.byKey(const Key('st-dots')), findsOneWidget);
    expect(find.byKey(const Key('st-token-0')), findsOneWidget);
    expect(find.byKey(const Key('st-token-1')), findsNothing);

    await _tapToken(tester, 0);
    await _flushSpeechChain(tester);

    // The tap spoke the token AND the finished line was read back fluently
    // (both utterances are 'cat' for this one-token line).
    expect(audio.speaks.where((s) => s == 'cat'), hasLength(2));

    // The view advanced to line 2 (four tokens now) — no tap between lines.
    expect(find.byKey(const Key('st-token-3')), findsOneWidget);
    expect(find.byKey(const Key('st-feedback')), findsNothing);

    // Line 2 reads left to right, each tapped token speaking itself.
    await _tapToken(tester, 0);
    expect(audio.speaks, contains('the'));
    await _tapToken(tester, 1);
    await _tapToken(tester, 2);
    expect(audio.speaks, contains('is'));
  });

  testWidgets(
      'completing the last line ends the story: feedback, ending speech, '
      'exactly one correct event', (tester) async {
    final audio = _RecordingAudioService();
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: StoryTimePage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // Line 1: [cat].
    await _tapToken(tester, 0);
    await _flushSpeechChain(tester);

    // Line 2: [the, cat, is, big].
    for (var i = 0; i < 4; i++) {
      await _tapToken(tester, i);
    }
    await _flushSpeechChain(tester);

    // The last line was read back fluently, then the ending was celebrated.
    expect(audio.speaks, contains('the cat is big'));
    expect(find.byKey(const Key('st-feedback')), findsOneWidget);
    expect(audio.speaks, contains('The end! You read a whole story!'));

    // Exactly one correct learning event, about the story's first token.
    expect(events, hasLength(1));
    expect(events.single.itemId, 'cat');
    expect(events.single.skill, 'read');
    expect(events.single.correct, isTrue);
    expect(events.single.game, 'story_time');
  });

  testWidgets('singleRound auto-reports a flawless round and hides the arrow',
      (tester) async {
    final audio = _RecordingAudioService();
    final completions = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: StoryTimePage(
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
    expect(find.byKey(const Key('st-next')), findsNothing);

    await _tapToken(tester, 0);
    await _flushSpeechChain(tester);
    for (var i = 0; i < 4; i++) {
      await _tapToken(tester, i);
    }
    await _flushSpeechChain(tester);

    expect(find.byKey(const Key('st-feedback')), findsOneWidget);
    expect(completions, isEmpty); // celebration first, then auto-advance

    await tester.pump(SingleRoundFlow.advanceDelay);
    await tester.pump();
    expect(completions, [true]);
    expect(find.byKey(const Key('st-next')), findsNothing);
  });

  testWidgets('with no stories the page says so and the lesson step skips',
      (tester) async {
    final audio = _RecordingAudioService();
    final completions = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: StoryTimePage(
        contentService: const _FakeContentService(withStories: false),
        audioService: audio,
        singleRound: true,
        onRoundComplete: ({required bool flawless}) =>
            completions.add(flawless),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('No stories yet.'), findsOneWidget);
    expect(completions, isEmpty);

    // The unplayable step quietly skips itself after a short beat.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(completions, [true]);
  });
}
