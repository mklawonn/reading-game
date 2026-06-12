import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/build_a_word/build_a_word_page.dart';
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
              id: 'o', type: 'letter_array', syllable: 'O', soundIpa: '', picturable: false),
          SyllableElement(
              id: 'pen', type: 'pictograph', syllable: 'pen', soundIpa: '', picturable: true),
          SyllableElement(
              id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
        ],
        words: [
          Word(id: 'open', text: 'open', segmentation: ['o', 'pen']),
        ],
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
  testWidgets('blends pieces placed in order into the target word',
      (tester) async {
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: BuildAWordPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(3),
      ),
    ));
    await tester.pumpAndSettle();

    // Target word is shown and spoken on round start.
    expect(find.byKey(const Key('bw-target')), findsOneWidget);
    expect(audio.spoken, contains('open'));

    // Tap the pieces in order: o, then pen → fills the two slots left-to-right.
    await tester.tap(find.byKey(const Key('bw-piece-o')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bw-piece-pen')));
    await tester.pumpAndSettle();

    // The blend is recognized.
    expect(find.byKey(const Key('bw-feedback')), findsOneWidget);
  });
}
