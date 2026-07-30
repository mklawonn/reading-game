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

/// Builds the ordered step plan for one lesson — the Duolingo-ABC-style
/// session shape (see docs/lessons.md):
///
///  * every not-yet-met symbol gets a Meet card **immediately followed by an
///    exercise focused on it** (new symbols are guaranteed practice — this also
///    sidesteps the sampler's working-set gate for unseen items);
///  * the rest of the lesson is filled from the level's game list in shuffled
///    "bags", never repeating a game back-to-back, so types stay varied;
///  * missed exercises are re-queued by the lesson screen at runtime (capped),
///    not planned here.
///
/// Pure Dart — fully unit-testable.
class LessonPlan {
  /// Exercises per lesson (intro-paired ones included) — short by design:
  /// a lesson should end while the child still wants more.
  static const int defaultExerciseCount = 8;

  /// Games that make a good *first meeting* with a brand-new symbol (they can
  /// target it directly and lean on listening). Order = preference.
  static const List<String> _introGames = [
    'listen_and_pick',
    'symbol_hunt',
    'find_the_character',
    'picture_to_word',
  ];

  static List<LessonStep> build({
    required CurriculumLevel level,
    required Set<String> seenIntros,
    int? exerciseCount,
    Random? random,
  }) {
    final rng = random ?? Random();
    final games =
        level.games.isEmpty ? const ['find_the_character'] : level.games;
    // Levels with little variety get *shorter* lessons — repetition is the
    // quit condition for this age, so run out of lesson before running out
    // of novelty.
    final count = exerciseCount ??
        (games.length < 3 ? defaultExerciseCount - 2 : defaultExerciseCount);

    final steps = <LessonStep>[];
    String? lastGame;

    // 1. Meet every new symbol, each chased by a focused exercise.
    final pending =
        level.introduce.where((id) => !seenIntros.contains(id)).toList();
    for (final id in pending) {
      steps.add(IntroStep(id));
      final game = _introGames.firstWhere(games.contains,
          orElse: () => games[rng.nextInt(games.length)]);
      steps.add(ExerciseStep(game, focusId: id));
      lastGame = game;
    }

    // 2. Fill the rest from shuffled bags so every game type gets airtime.
    var remaining = max(count - pending.length, pending.isEmpty ? 4 : 2);
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
    return steps;
  }
}
