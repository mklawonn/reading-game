/// One level of the guided curriculum (see `content/curriculum.v1.json`).
///
/// A level [introduce]s a few new symbols (element ids) and lists the [games]
/// appropriate for it. The pool of symbols available *at* a level is the union
/// of `introduce` over all levels up to and including it — so a symbol is always
/// taught (a Meet card) before any game can use it.
class CurriculumLevel {
  const CurriculumLevel({
    required this.id,
    required this.stage,
    required this.title,
    required this.introduce,
    required this.games,
    required this.xpToAdvance,
    this.lessons = 2,
    this.story = false,
  });

  final int id;
  final int stage;
  final String title;
  final List<String> introduce; // element ids newly taught this level
  final List<String> games; // game ids playable this level
  final int xpToAdvance; // XP to reach the next level (legacy reward curve)
  final int lessons; // short lessons to complete before leveling up

  /// Whether this level's lesson rotation includes a Story Time node (set in
  /// the schedule wherever `stories.v1.json` has an unlocked story).
  final bool story;

  factory CurriculumLevel.fromJson(Map<String, dynamic> json) => CurriculumLevel(
        id: json['id'] as int,
        stage: json['stage'] as int? ?? 1,
        title: json['title'] as String? ?? 'Level ${json['id']}',
        introduce: (json['introduce'] as List<dynamic>? ?? const [])
            .map((s) => s as String)
            .toList(growable: false),
        games: (json['games'] as List<dynamic>? ?? const [])
            .map((s) => s as String)
            .toList(growable: false),
        xpToAdvance: json['xpToAdvance'] as int? ?? 50,
        lessons: json['lessons'] as int? ?? 2,
        story: json['story'] as bool? ?? false,
      );
}

/// A themed "world" grouping consecutive levels — the top tier of the
/// worlds → sub-levels → lesson-nodes hierarchy (docs/lessons.md). Rendered
/// as an emoji landmark on the home screen's world strip.
class CurriculumUnit {
  const CurriculumUnit({
    required this.id,
    required this.title,
    required this.emoji,
    required this.levels,
  });

  final int id;
  final String title;
  final String emoji;

  /// The 1-based level ids belonging to this unit, in order.
  final List<int> levels;

  factory CurriculumUnit.fromJson(Map<String, dynamic> json) => CurriculumUnit(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'World ${json['id']}',
        emoji: json['emoji'] as String? ?? '⭐',
        levels: (json['levels'] as List<dynamic>? ?? const [])
            .map((l) => l as int)
            .toList(growable: false),
      );
}

/// The ordered curriculum schedule (`assets/content/curriculum.v1.json`).
class CurriculumSchedule {
  const CurriculumSchedule({
    required this.version,
    required this.levels,
    this.units = const [],
  });

  final String version;
  final List<CurriculumLevel> levels;

  /// The world tier. Empty for schedules that predate units — [unitFor] then
  /// falls back to one catch-all world so the home screen always renders.
  final List<CurriculumUnit> units;

  int get length => levels.length;

  /// The level numbered [n] (1-based), clamped into range.
  CurriculumLevel levelAt(int n) =>
      levels[(n - 1).clamp(0, levels.length - 1)];

  /// The unit containing level [n] (a catch-all when no units are defined).
  CurriculumUnit unitFor(int n) {
    for (final u in units) {
      if (u.levels.contains(n)) return u;
    }
    return CurriculumUnit(
      id: 1,
      title: 'Reading Path',
      emoji: '⭐',
      levels: [for (var i = 1; i <= length; i++) i],
    );
  }

  factory CurriculumSchedule.fromJson(Map<String, dynamic> json) =>
      CurriculumSchedule(
        version: json['version'] as String? ?? '0',
        levels: (json['levels'] as List<dynamic>? ?? const <dynamic>[])
            .map((l) => CurriculumLevel.fromJson(l as Map<String, dynamic>))
            .toList(growable: false),
        units: (json['units'] as List<dynamic>? ?? const <dynamic>[])
            .map((u) => CurriculumUnit.fromJson(u as Map<String, dynamic>))
            .toList(growable: false),
      );
}
