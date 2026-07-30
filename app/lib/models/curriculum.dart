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
  });

  final int id;
  final int stage;
  final String title;
  final List<String> introduce; // element ids newly taught this level
  final List<String> games; // game ids playable this level
  final int xpToAdvance; // XP to reach the next level (legacy reward curve)
  final int lessons; // short lessons to complete before leveling up

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
      );
}

/// The ordered curriculum schedule (`assets/content/curriculum.v1.json`).
class CurriculumSchedule {
  const CurriculumSchedule({required this.version, required this.levels});

  final String version;
  final List<CurriculumLevel> levels;

  int get length => levels.length;

  /// The level numbered [n] (1-based), clamped into range.
  CurriculumLevel levelAt(int n) =>
      levels[(n - 1).clamp(0, levels.length - 1)];

  factory CurriculumSchedule.fromJson(Map<String, dynamic> json) =>
      CurriculumSchedule(
        version: json['version'] as String? ?? '0',
        levels: (json['levels'] as List<dynamic>? ?? const <dynamic>[])
            .map((l) => CurriculumLevel.fromJson(l as Map<String, dynamic>))
            .toList(growable: false),
      );
}
