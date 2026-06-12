import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/content/syllable_tile.dart';
import 'package:reading_game/features/find_the_character/find_the_character_page.dart';
import 'package:reading_game/models/content_bank.dart';
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

void main() {
  testWidgets('shows a written word and accepts the matching picture',
      (tester) async {
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: FindTheCharacterPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(2),
      ),
    ));
    await tester.pumpAndSettle();

    // The written prompt is shown; its text is the target syllable (== id here).
    final prompt = tester.widget<SyllableTile>(find.byKey(const Key('fc-prompt')));
    final target = prompt.syllable;

    await tester.tap(find.byKey(Key('fc-option-$target')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fc-feedback')), findsOneWidget);
  });
}
