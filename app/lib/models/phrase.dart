/// A short phrase for the Fill-in-the-Blank game. Every token is a Content Bank
/// element id, and one token (at [blank]) is the slot the child fills. Because
/// the tokens are content ids — not baked-in glyphs — the same phrase renders in
/// whatever orthography the child's current stage calls for (pictographs early,
/// letters later), which is how a phrase repeats across stages.
class Phrase {
  const Phrase({
    required this.id,
    required this.tokens,
    required this.blank,
    this.distractors = const [],
  });

  final String id;

  /// Ordered element ids; [tokens]`[`[blank]`]` is the answer.
  final List<String> tokens;
  final int blank;

  /// Optional curated wrong-answer element ids; if empty the game derives them.
  final List<String> distractors;

  String get answer => tokens[blank];

  factory Phrase.fromJson(Map<String, dynamic> json) => Phrase(
        id: json['id'] as String,
        tokens: (json['tokens'] as List<dynamic>)
            .map((t) => t as String)
            .toList(growable: false),
        blank: json['blank'] as int,
        distractors: (json['distractors'] as List<dynamic>? ?? const [])
            .map((t) => t as String)
            .toList(growable: false),
      );
}

/// The bundled phrase collection (`assets/content/phrases.v1.json`).
class PhraseSet {
  const PhraseSet({required this.version, required this.phrases});

  final String version;
  final List<Phrase> phrases;

  factory PhraseSet.fromJson(Map<String, dynamic> json) => PhraseSet(
        version: json['version'] as String? ?? '0',
        phrases: (json['phrases'] as List<dynamic>? ?? const <dynamic>[])
            .map((p) => Phrase.fromJson(p as Map<String, dynamic>))
            .toList(growable: false),
      );
}
