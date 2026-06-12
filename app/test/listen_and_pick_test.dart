import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/listen_and_pick/listen_and_pick_page.dart';
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
  testWidgets('speaks a target syllable and accepts the matching picture',
      (tester) async {
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: ListenAndPickPage(
        contentService: const _FakeContentService(),
        audioService: audio,
        random: Random(1),
      ),
    ));
    await tester.pumpAndSettle();

    // The round names its target aloud as an instruction ("Tap the sun!").
    expect(audio.spoken, isNotEmpty);
    final said = audio.spoken.last;
    expect(said, startsWith('Tap the '));
    final target =
        said.substring('Tap the '.length, said.length - 1); // strip the "!"

    // Tapping the picture that matches the heard syllable solves the round.
    await tester.tap(find.byKey(Key('lp-option-$target')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lp-feedback')), findsOneWidget);
  });
}
