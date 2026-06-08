import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/models/phoneme.dart';
import 'package:reading_game/services/audio_service.dart';

class _RecordingAudio implements AudioService {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text) async => spoken.add(text);
}

void main() {
  test('Phoneme.fromJson maps fields and derives stretchy', () {
    final stop = Phoneme.fromJson(
        {'ipa': 'b', 'kind': 'stop', 'stop': true, 'voiced': true, 'anchor': 'ball'});
    expect(stop.isStop, isTrue);
    expect(stop.stretchy, isFalse);
    expect(stop.voiced, isTrue);
    expect(stop.anchor, 'ball');

    final cont = Phoneme.fromJson(
        {'ipa': 's', 'kind': 'fricative', 'stop': false, 'voiced': false, 'anchor': 'sun'});
    expect(cont.isStop, isFalse);
    expect(cont.stretchy, isTrue);
  });

  test('speakPhoneme: a stop is anchored in its keyword, never voiced alone',
      () async {
    final audio = _RecordingAudio();
    const k = Phoneme(
        ipa: 'k', kind: 'stop', isStop: true, voiced: false, anchor: 'key');
    await audio.speakPhoneme(k, anchorSyllable: 'key');
    expect(audio.spoken, ['key']); // the keyword, not a bare /k/
  });

  test('speakPhoneme: a continuant is stretched, not spoken as the bare letter',
      () async {
    final audio = _RecordingAudio();
    const s = Phoneme(
        ipa: 's', kind: 'fricative', isStop: false, voiced: false, anchor: 'sun');
    await audio.speakPhoneme(s, anchorSyllable: 'sun');
    final said = audio.spoken.single;
    expect(said, isNot('s')); // held form, e.g. "ssss"
    expect(said.length, greaterThan(1));
  });
}
