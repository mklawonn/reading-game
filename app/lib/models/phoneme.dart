/// A single English phoneme used by the Stage-1 vocabulary.
///
/// The pedagogically load-bearing fields are [isStop] and [anchor]:
///  * **stops** (p, b, t, d, k, ɡ) cannot be voiced in isolation — they are
///    taught by contrast and in word context, and their "sound" is presented via
///    the [anchor] keyword ("/k/ as in key"). See docs/curriculum.md.
///  * everything else is a **continuant** ("stretchy") and *can* be sustained.
/// [voiced] supports the voiced/voiceless twin-pairs lesson (p–b, t–d, k–ɡ).
class Phoneme {
  const Phoneme({
    required this.ipa,
    required this.kind,
    required this.isStop,
    required this.voiced,
    required this.anchor,
  });

  final String ipa;

  /// stop | fricative | nasal | approximant | vowel | diphthong.
  final String kind;

  /// True for the six stops — cannot be cleanly isolated.
  final bool isStop;
  final bool voiced;

  /// Picturable element id where this sound is salient (keyword anchor).
  final String anchor;

  /// Kid-facing class: stops "pop", everything else is "stretchy".
  bool get stretchy => !isStop;

  factory Phoneme.fromJson(Map<String, dynamic> json) => Phoneme(
        ipa: json['ipa'] as String,
        kind: json['kind'] as String? ?? '',
        isStop: json['stop'] as bool? ?? false,
        voiced: json['voiced'] as bool? ?? false,
        anchor: json['anchor'] as String? ?? '',
      );
}

/// The bundled phoneme inventory (`assets/content/phonemes.v1.json`).
class PhonemeSet {
  PhonemeSet({required this.version, required this.phonemes})
      : _byIpa = {for (final p in phonemes) p.ipa: p};

  final String version;
  final List<Phoneme> phonemes;
  final Map<String, Phoneme> _byIpa;

  Phoneme? byIpa(String ipa) => _byIpa[ipa];

  factory PhonemeSet.fromJson(Map<String, dynamic> json) => PhonemeSet(
        version: json['version'] as String? ?? '0',
        phonemes: (json['phonemes'] as List<dynamic>? ?? const <dynamic>[])
            .map((p) => Phoneme.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
      );
}
