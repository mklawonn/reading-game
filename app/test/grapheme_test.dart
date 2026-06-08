import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/models/content_bank.dart';

void main() {
  test('SyllableElement parses graphemes, incl. multi-letter and x→ks', () {
    final e = SyllableElement.fromJson({
      'id': 'fox',
      'type': 'pictograph',
      'syllable': 'fox',
      'sound_ipa': 'fɒks',
      'picturable': true,
      'graphemes': [
        {'g': 'f', 'p': 'f'},
        {'g': 'o', 'p': 'ɒ'},
        {'g': 'x', 'p': 'ks'}, // one letter, two phonemes
      ],
    });
    expect(e.graphemes.length, 3);
    // Concatenation reconstructs the spelling and the phoneme string.
    expect(e.graphemes.map((g) => g.letters).join(), 'fox');
    expect(e.graphemes.map((g) => g.phoneme).join(), 'fɒks');
    expect(e.graphemes.last.phoneme, 'ks');
  });

  test('a multi-letter grapheme stays one unit', () {
    final e = SyllableElement.fromJson({
      'id': 'bee',
      'type': 'pictograph',
      'syllable': 'bee',
      'sound_ipa': 'biː',
      'picturable': true,
      'graphemes': [
        {'g': 'b', 'p': 'b'},
        {'g': 'ee', 'p': 'iː'},
      ],
    });
    expect(e.graphemes.length, 2);
    expect(e.graphemes.last.letters, 'ee');
    expect(e.graphemes.last.phoneme, 'iː');
  });

  test('graphemes default to empty when absent', () {
    final e = SyllableElement.fromJson({
      'id': 'the',
      'type': 'letter_array',
      'syllable': 'the',
      'sound_ipa': 'ðə',
      'picturable': false,
    });
    expect(e.graphemes, isEmpty);
  });
}
