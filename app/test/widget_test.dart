// Widget test for the Stage-1 tap-to-hear demo. Injects an in-memory Content
// Bank and a fake AudioService so it runs hermetically (no assets, no TTS).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/pictograph_demo/pictograph_demo_page.dart';
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
            id: 'can',
            type: 'pictograph',
            syllable: 'can',
            soundIpa: 'kæn',
            picturable: true,
            imageRef: 'can.png',
            audioRef: 'can.mp3',
          ),
          SyllableElement(
            id: 'sun',
            type: 'pictograph',
            syllable: 'sun',
            soundIpa: 'sʌn',
            picturable: true,
            imageRef: 'sun.png',
            audioRef: 'sun.mp3',
          ),
          SyllableElement(
            id: 'and',
            type: 'letter_array',
            syllable: 'and',
            soundIpa: 'ænd',
            picturable: false,
          ),
        ],
        words: [],
      );
}

class _FakeAudioService implements AudioService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async => spoken.add(text);
}

void main() {
  testWidgets('renders a card per pictograph and speaks its sound on tap',
      (tester) async {
    final audio = _FakeAudioService();

    await tester.pumpWidget(MaterialApp(
      home: PictographDemoPage(
        contentService: const _FakeContentService(),
        audioService: audio,
      ),
    ));
    await tester.pumpAndSettle(); // resolve the content-load FutureBuilder

    // Only the two picturable elements render as cards; the letter-array does not.
    expect(find.text('can'), findsOneWidget);
    expect(find.text('sun'), findsOneWidget);
    expect(find.text('and'), findsNothing);

    await tester.tap(find.text('can'));
    await tester.pump();
    expect(audio.spoken, contains('can'));
  });
}
