import 'dart:math';

import '../models/curriculum.dart';

/// One step of a lesson.
sealed class LessonStep {
  const LessonStep();
}

/// Show the "Meet this symbol" card for [symbolId].
class IntroStep extends LessonStep {
  const IntroStep(this.symbolId);
  final String symbolId;
}

/// Play one round of [gameId], optionally focused on [focusId] (a
/// just-introduced symbol, or a missed item being re-practiced).
class ExerciseStep extends LessonStep {
  const ExerciseStep(this.gameId, {this.focusId});
  final String gameId;
  final String? focusId;
}

/// What a lesson is *about*. Every lesson has one focus instead of a random
/// game salad (see docs/lessons.md):
///
///  * [meet] — the level's first lesson(s): teach each new symbol, then drill
///    it immediately in an escalating block (hear it → hunt it → read it);
///  * [sounds] — middle lessons: listening and matching games;
///  * [reading] — the level's last lesson: print-direction games, opening
///    with the level's new symbols for retention.
enum LessonTheme { meet, sounds, reading }

/// Builds the ordered step plan for one lesson. Pure Dart — unit-testable.
class LessonPlan {
  /// Exercises per lesson — short by design: a lesson should end while the
  /// child still wants more.
  static const int defaultExerciseCount = 8;

  /// Ear-first games: the child listens/matches; print plays no role or a
  /// supporting one.
  static const Set<String> soundGames = {
    'listen_and_pick', 'sound_match', 'symbol_hunt', 'families',
  };

  /// Print-direction games: the child decodes or composes written forms.
  static const Set<String> readingGames = {
    'find_the_character', 'picture_to_word', 'echo_read',
    'fill_blank', 'build_a_word', 'blend_reveal',
  };

  /// The escalating drill block for a just-met symbol, in teaching order:
  /// hear→picture first, playful recognition next, the print link last —
  /// so reading a symbol is always preceded by owning its sound.
  static const List<String> _drillOrder = [
    'listen_and_pick',
    'symbol_hunt',
    'sound_match',
    'find_the_character',
    'picture_to_word',
  ];

  /// The theme this lesson should carry: meet while any of the level's
  /// symbols are unmet, else sounds for middle lessons and reading to close
  /// the level out.
  static LessonTheme themeFor({
    required CurriculumLevel level,
    required Set<String> seenIntros,
    required int lessonIndex,
  }) {
    if (level.introduce.any((id) => !seenIntros.contains(id))) {
      return LessonTheme.meet;
    }
    return lessonIndex >= level.lessons - 1
        ? LessonTheme.reading
        : LessonTheme.sounds;
  }

  static List<LessonStep> build({
    required CurriculumLevel level,
    required Set<String> seenIntros,
    int lessonIndex = 0,
    int? exerciseCount,
    Random? random,
  }) {
    final rng = random ?? Random();
    final games =
        level.games.isEmpty ? const ['find_the_character'] : level.games;
    final theme = themeFor(
        level: level, seenIntros: seenIntros, lessonIndex: lessonIndex);
    return switch (theme) {
      LessonTheme.meet =>
        _meetLesson(level, seenIntros, games, exerciseCount, rng),
      _ => _themedLesson(level, games, theme, exerciseCount, rng),
    };
  }

  /// Teach-then-drill: every unmet symbol gets its Meet card followed
  /// immediately by an escalating block of exercises focused on it — the
  /// retention drilling happens *now*, not three exercises later.
  static List<LessonStep> _meetLesson(
    CurriculumLevel level,
    Set<String> seenIntros,
    List<String> games,
    int? exerciseCount,
    Random rng,
  ) {
    final pending =
        level.introduce.where((id) => !seenIntros.contains(id)).toList();
    var drills = _drillOrder.where(games.contains).toList();
    if (drills.isEmpty) drills = [games.first];
    // Three drills per symbol; two when meeting many at once keeps the
    // lesson bite-sized.
    final perSymbol = min(pending.length >= 3 ? 2 : 3, drills.length);

    final steps = <LessonStep>[];
    String? lastGame;
    for (final id in pending) {
      steps.add(IntroStep(id));
      for (final game in drills.take(perSymbol)) {
        steps.add(ExerciseStep(game, focusId: id));
        lastGame = game;
      }
    }

    // Top up with mixed review so a one-symbol lesson still has substance.
    final drilled = pending.length * perSymbol;
    final target = exerciseCount ?? max(6, drilled);
    _fillFromBags(steps, games, target - drilled, lastGame, rng);
    return steps;
  }

  /// A focused practice lesson: only this theme's games (falling back to the
  /// level's full list when it can't fill the theme), opening with the
  /// level's own new symbols so fresh material keeps resurfacing.
  static List<LessonStep> _themedLesson(
    CurriculumLevel level,
    List<String> games,
    LessonTheme theme,
    int? exerciseCount,
    Random rng,
  ) {
    final themeSet =
        theme == LessonTheme.reading ? readingGames : soundGames;
    var pool = games.where(themeSet.contains).toList();
    if (pool.length < 2) pool = List.of(games);
    final count = exerciseCount ?? (pool.length < 3 ? 6 : defaultExerciseCount);

    final steps = <LessonStep>[];
    String? lastGame;
    // Retention: open by re-drilling this level's new symbols.
    final fresh = List.of(level.introduce)..shuffle(rng);
    for (final id in fresh.take(min(2, count))) {
      final game = _pickAvoiding(pool, lastGame, rng);
      steps.add(ExerciseStep(game, focusId: id));
      lastGame = game;
    }
    _fillFromBags(steps, pool, count - steps.length, lastGame, rng);
    return steps;
  }

  static String _pickAvoiding(List<String> pool, String? avoid, Random rng) {
    final options = pool.length > 1 && avoid != null
        ? pool.where((g) => g != avoid).toList()
        : pool;
    return options[rng.nextInt(options.length)];
  }

  /// Appends [remaining] exercises drawn from shuffled "bags" of [games] so
  /// every type gets airtime and no game repeats back-to-back.
  static void _fillFromBags(
    List<LessonStep> steps,
    List<String> games,
    int remaining,
    String? lastGame,
    Random rng,
  ) {
    var bag = <String>[];
    while (remaining > 0) {
      if (bag.isEmpty) bag = [...games]..shuffle(rng);
      var pick = bag.removeAt(0);
      if (pick == lastGame && (bag.isNotEmpty || games.length > 1)) {
        if (bag.isEmpty) bag = [...games]..shuffle(rng);
        // Swap in the next different game; drop the repeat back in the bag.
        final swapIndex = bag.indexWhere((g) => g != lastGame);
        if (swapIndex != -1) {
          final swap = bag.removeAt(swapIndex);
          bag.add(pick);
          pick = swap;
        }
      }
      steps.add(ExerciseStep(pick));
      lastGame = pick;
      remaining--;
    }
  }
}
