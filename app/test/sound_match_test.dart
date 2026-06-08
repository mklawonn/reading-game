import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/sound_match/sound_match_page.dart';
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
  testWidgets('matching every symbol to its sound solves the round',
      (tester) async {
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: SoundMatchPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudioService(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // All three pairs are present (setSize 3, pool 3).
    for (final id in const ['sun', 'bee', 'pup']) {
      await _dragOnto(
        tester,
        find.byKey(Key('sm-symbol-$id')),
        find.byKey(Key('sm-sound-$id')),
      );
    }

    // Correct matches recorded for each item, and the round is solved.
    expect(events.where((e) => e.correct).map((e) => e.itemId).toSet(),
        {'sun', 'bee', 'pup'});
    expect(events.every((e) => e.skill == 'match'), isTrue);
    expect(find.byKey(const Key('sm-feedback')), findsOneWidget);
  });

  testWidgets('dropping a symbol on the wrong sound records an error',
      (tester) async {
    final events = <LearningEvent>[];

    await tester.pumpWidget(MaterialApp(
      home: SoundMatchPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudioService(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    await _dragOnto(
      tester,
      find.byKey(const Key('sm-symbol-sun')),
      find.byKey(const Key('sm-sound-bee')),
    );

    expect(events.single.correct, isFalse);
    expect(events.single.itemId, 'sun');
    expect(find.byKey(const Key('sm-feedback')), findsNothing);
  });
}
