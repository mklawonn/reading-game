import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/families/families_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/phoneme.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/services/audio_service.dart';
import 'package:reading_game/services/content_service.dart';

// cat/hat share rime "at" → a rhyme family of 2; dog/sun are singletons → only
// cat & hat are playable, and only rhyme mode is available (no grapheme onsets).
class _FakeContentService extends ContentService {
  const _FakeContentService();

  @override
  Future<ContentBank> load() async => const ContentBank(
        version: '0',
        elements: [
          SyllableElement(
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: 'kæt', picturable: true, rhymeGroup: 'at'),
          SyllableElement(
              id: 'hat', type: 'pictograph', syllable: 'hat', soundIpa: 'hæt', picturable: true, rhymeGroup: 'at'),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: 'dɒɡ', picturable: true, rhymeGroup: 'og'),
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: 'sʌn', picturable: true, rhymeGroup: 'un'),
        ],
        words: [],
      );

  @override
  Future<PhonemeSet> loadPhonemes() async =>
      PhonemeSet(version: '0', phonemes: const []);
}

class _FakeAudio implements AudioService {
  @override
  Future<void> speak(String text) async {}
}

void main() {
  testWidgets('tapping the rhyming word solves the round', (tester) async {
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: FamiliesPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudio(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // The answer is whichever of cat/hat is offered as an option (the other is
    // the prompt). Exactly one is present.
    final answer = find.byKey(const Key('fam-option-cat')).evaluate().isNotEmpty
        ? const Key('fam-option-cat')
        : const Key('fam-option-hat');
    await tester.tap(find.byKey(answer));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fam-feedback')), findsOneWidget);
    expect(events.single.correct, isTrue);
    expect(events.single.skill, 'rhyme');
  });

  testWidgets('a non-family word is wrong', (tester) async {
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: FamiliesPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudio(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    // dog is never in the "at" family → always a distractor.
    await tester.tap(find.byKey(const Key('fam-option-dog')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fam-wrong')), findsOneWidget);
    expect(find.byKey(const Key('fam-feedback')), findsNothing);
    expect(events.single.correct, isFalse);
  });
}
