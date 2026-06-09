import 'dart:math';

import '../models/content_bank.dart';
import '../models/curriculum.dart';

/// What the guided home should run next.
sealed class NextActivity {
  const NextActivity();
}

/// Show the "Meet this symbol" card for [symbolId] (introduce-before-use).
class IntroduceActivity extends NextActivity {
  const IntroduceActivity(this.symbolId);
  final String symbolId;
}

/// Launch the game [gameId], scoped to the currently-introduced symbols.
class GameActivity extends NextActivity {
  const GameActivity(this.gameId);
  final String gameId;
}

/// Turns the [CurriculumSchedule] + the child's level/seen-intros into "what
/// next", and computes the **scoped symbol pool** for a level so games only ever
/// draw from already-taught symbols (the fix for stage-skipping). Pure and
/// Flutter-free — unit-testable; the profile's level/seen state is passed in.
class CurriculumEngine {
  CurriculumEngine({required this.schedule, required this.bank, Random? random})
      : _random = random ?? Random();

  final CurriculumSchedule schedule;
  final ContentBank bank;
  final Random _random;

  /// Element ids introduced through [level] (union of `introduce`, 1..level).
  Set<String> introducedThrough(int level) {
    final out = <String>{};
    for (var i = 1; i <= level && i <= schedule.length; i++) {
      out.addAll(schedule.levelAt(i).introduce);
    }
    return out;
  }

  /// This level's new symbols the child hasn't met yet (in `introduce` order).
  List<String> pendingIntros(int level, Set<String> seen) =>
      schedule.levelAt(level).introduce.where((id) => !seen.contains(id)).toList();

  /// Picturable elements introduced through [level] — the scoped game pool.
  List<SyllableElement> scopedPool(int level) {
    final ids = introducedThrough(level);
    return bank.elements
        .where((e) => e.picturable && ids.contains(e.id))
        .toList(growable: false);
  }

  /// The next thing to do: introduce any not-yet-met symbol first, else a game
  /// from this level (avoiding an immediate repeat of [lastGame] when possible).
  NextActivity next(int level, Set<String> seen, {String? lastGame}) {
    final pending = pendingIntros(level, seen);
    if (pending.isNotEmpty) return IntroduceActivity(pending.first);

    final games = schedule.levelAt(level).games;
    if (games.isEmpty) return const GameActivity('find_the_character');
    final fresh = games.length > 1 && lastGame != null
        ? games.where((g) => g != lastGame).toList()
        : games;
    final pool = fresh.isEmpty ? games : fresh;
    return GameActivity(pool[_random.nextInt(pool.length)]);
  }
}
