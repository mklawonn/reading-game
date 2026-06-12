import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/content/glyph_view.dart';
import 'package:reading_game/content/syllable_tile.dart';
import 'package:reading_game/features/fill_blank/fill_blank_page.dart';
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
              id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'i', type: 'pictograph', syllable: 'I', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'see', type: 'letter_array', syllable: 'see', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'a', type: 'letter_array', syllable: 'a', soundIpa: '', picturable: false),
        ],
        words: [],
      );

  @override
  Future<PhraseSet> loadPhrases() async => const PhraseSet(
        version: '0',
        phrases: [
          Phrase(id: 'i_see_a_cat', tokens: ['i', 'see', 'a', 'cat'], blank: 3),
        ],
      );
}

class _FakeAudioService implements AudioService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
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
  testWidgets('dragging the right symbol into the blank solves the phrase',
      (tester) async {
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: FillBlankPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudioService(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    await _dragOnto(tester, find.byKey(const Key('fb-option-cat')),
        find.byKey(const Key('fb-slot')));

    expect(find.byKey(const Key('fb-feedback')), findsOneWidget);
    expect(events.single.itemId, 'cat');
    expect(events.single.skill, 'read');
    expect(events.single.correct, isTrue);
  });

  testWidgets('a wrong symbol is rejected and recorded', (tester) async {
    final events = <LearningEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: FillBlankPage(
        contentService: const _FakeContentService(),
        audioService: _FakeAudioService(),
        random: Random(1),
        onEvent: events.add,
      ),
    ));
    await tester.pumpAndSettle();

    await _dragOnto(tester, find.byKey(const Key('fb-option-dog')),
        find.byKey(const Key('fb-slot')));

    expect(find.byKey(const Key('fb-wrong')), findsOneWidget);
    expect(find.byKey(const Key('fb-feedback')), findsNothing);
    expect(events.single.correct, isFalse);
  });

  testWidgets('the same phrase renders as pictures at Stage 1, letters at Stage 2',
      (tester) async {
    Widget page(int stage) => MaterialApp(
          home: FillBlankPage(
            contentService: const _FakeContentService(),
            audioService: _FakeAudioService(),
            stage: stage,
            random: Random(1),
          ),
        );

    await tester.pumpWidget(page(1));
    await tester.pumpAndSettle();
    // Picturable tokens/candidates render as pictures at Stage 1.
    expect(find.byType(GlyphView), findsWidgets);

    await tester.pumpWidget(page(2));
    await tester.pumpAndSettle();
    // At Stage 2 the very same content renders as linked letters — no pictures.
    expect(find.byType(GlyphView), findsNothing);
    expect(find.byType(SyllableTile), findsWidgets);
  });
}
