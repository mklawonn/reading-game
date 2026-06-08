/// Dart models for the Reading Game Content Bank.
///
/// The bank (see `content/schema.md`) is the single source of truth for every
/// symbol and word. It has two collections: [elements] (atomic syllable-symbols)
/// and [words] (single elements or blends of elements).
library;

class ContentBank {
  const ContentBank({
    required this.version,
    required this.elements,
    required this.words,
  });

  final String version;
  final List<SyllableElement> elements;
  final List<Word> words;

  factory ContentBank.fromJson(Map<String, dynamic> json) {
    return ContentBank(
      version: json['version'] as String? ?? '0',
      elements: (json['elements'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => SyllableElement.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      words: (json['words'] as List<dynamic>? ?? const <dynamic>[])
          .map((w) => Word.fromJson(w as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// The picturable atomic symbols — the Stage-1 pictographs shown in the demo.
  List<SyllableElement> get pictographs =>
      elements.where((e) => e.picturable).toList(growable: false);
}

/// An atomic syllable-symbol: `pictograph`, `glyph`, `letter_array`, or `letter`.
class SyllableElement {
  const SyllableElement({
    required this.id,
    required this.type,
    required this.syllable,
    required this.soundIpa,
    required this.picturable,
    this.imageRef,
    this.audioRef,
    this.introducedStage = 1,
    this.graphemes = const [],
  });

  final String id;
  final String type;
  final String syllable;
  final String soundIpa;
  final bool picturable;

  /// Path under `assets/images/pictographs/` (may be null / not yet on disk).
  final String? imageRef;

  /// Path under `assets/audio/` for the syllable sound (placeholder in M0).
  final String? audioRef;

  /// Earliest curriculum stage this element appears in (drives stage progress).
  final int introducedStage;

  /// Letter-group → phoneme decoding map: the spelling split into graphemes
  /// (e.g. `rain` → r·ai·n = /ɹ·eɪ·n/). Present for decodable picturable words,
  /// empty otherwise. Powers Stage-4 letter/phoneme work (multi-letter graphemes
  /// like `ee`/`ai`/`ng`, and `x`→/ks/).
  final List<Grapheme> graphemes;

  factory SyllableElement.fromJson(Map<String, dynamic> json) {
    return SyllableElement(
      id: json['id'] as String,
      type: json['type'] as String,
      syllable: json['syllable'] as String,
      soundIpa: json['sound_ipa'] as String? ?? '',
      picturable: json['picturable'] as bool? ?? false,
      imageRef: json['image_ref'] as String?,
      audioRef: json['audio_ref'] as String?,
      introducedStage: json['introduced_stage'] as int? ?? 1,
      graphemes: (json['graphemes'] as List<dynamic>? ?? const <dynamic>[])
          .map((g) => Grapheme.fromJson(g as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// One spelling-unit of a word: [letters] (one or more, e.g. `sh`) mapping to a
/// single [phoneme] in IPA (e.g. `ʃ`) — except `x`→`ks` (one letter, two
/// phonemes). Concatenating a word's graphemes reproduces both its spelling and
/// its `sound_ipa`.
class Grapheme {
  const Grapheme({required this.letters, required this.phoneme});

  final String letters;
  final String phoneme;

  factory Grapheme.fromJson(Map<String, dynamic> json) => Grapheme(
        letters: json['g'] as String,
        phoneme: json['p'] as String,
      );
}

/// A word: a single element (e.g. `can`) or a blend (e.g. `open` = `o` + `pen`).
class Word {
  const Word({
    required this.id,
    required this.text,
    required this.segmentation,
    this.audioRef,
    this.isTestBlend = false,
  });

  final String id;
  final String text;

  /// Element ids whose sounds blend to this word.
  final List<String> segmentation;
  final String? audioRef;

  /// Held out for assessment (never explicitly taught), per Gleitman & Rozin.
  final bool isTestBlend;

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String,
      text: json['text'] as String,
      segmentation: (json['segmentation'] as List<dynamic>? ?? const <dynamic>[])
          .map((s) => s as String)
          .toList(growable: false),
      audioRef: json['audio_ref'] as String?,
      isTestBlend: json['is_test_blend'] as bool? ?? false,
    );
  }
}
