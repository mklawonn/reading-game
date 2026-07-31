/// A tap-along story for Story Time lesson nodes. Lines are sequences of
/// Content Bank element ids, so a story renders in whatever orthography the
/// child's stage calls for. Stories may reach beyond the taught pool — the
/// child taps along and hears every token; nothing is quizzed.
class Story {
  const Story({
    required this.id,
    required this.title,
    required this.unlockLevel,
    required this.lines,
  });

  final String id;

  /// Parent-facing name (children meet the story through its pictures).
  final String title;

  /// First curriculum level whose Story Time lessons may pick this story.
  final int unlockLevel;

  /// Ordered lines, each an ordered list of element ids.
  final List<List<String>> lines;

  factory Story.fromJson(Map<String, dynamic> json) => Story(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        unlockLevel: json['unlock_level'] as int? ?? 1,
        lines: [
          for (final line in json['lines'] as List<dynamic>? ?? const [])
            [for (final t in line as List<dynamic>) t as String],
        ],
      );
}

/// The bundled story collection (`assets/content/stories.v1.json`).
class StorySet {
  const StorySet({required this.version, required this.stories});

  final String version;
  final List<Story> stories;

  /// Stories available at [level], newest unlocks first — tales grow with
  /// the reader.
  List<Story> unlockedAt(int level) =>
      (stories.where((s) => s.unlockLevel <= level).toList()
        ..sort((a, b) => b.unlockLevel.compareTo(a.unlockLevel)));

  factory StorySet.fromJson(Map<String, dynamic> json) => StorySet(
        version: json['version'] as String? ?? '0',
        stories: (json['stories'] as List<dynamic>? ?? const [])
            .map((s) => Story.fromJson(s as Map<String, dynamic>))
            .toList(growable: false),
      );
}
