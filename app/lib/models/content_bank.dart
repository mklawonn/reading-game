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

  factory SyllableElement.fromJson(Map<String, dynamic> json) {
    return SyllableElement(
      id: json['id'] as String,
      type: json['type'] as String,
      syllable: json['syllable'] as String,
      soundIpa: json['sound_ipa'] as String? ?? '',
      picturable: json['picturable'] as bool? ?? false,
      imageRef: json['image_ref'] as String?,
      audioRef: json['audio_ref'] as String?,
    );
  }
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
