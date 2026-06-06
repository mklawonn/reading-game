/// The decoupling seam between game mechanics and the progression layer.
///
/// A game emits a [LearningEvent] whenever the child answers; the progression
/// engine consumes it. The engine never references specific content — it only
/// sees an opaque [itemId], a [skill] tag, the curriculum [stage], and whether
/// the answer was [correct]. So the curriculum can change freely without
/// touching either the games or the progression engine.
class LearningEvent {
  const LearningEvent({
    required this.itemId,
    required this.skill,
    required this.stage,
    required this.correct,
    required this.game,
  });

  /// Content Bank entry id (element or word) the answer was about.
  final String itemId;

  /// What the answer exercised, e.g. `recognize` or `blend`. Free-form so new
  /// skills can be added in content/curriculum without code changes.
  final String skill;

  /// Curriculum stage the item belongs to (1 = pictographs, 2 = syllables, …).
  final int stage;

  final bool correct;

  /// Id of the emitting game (the modality), e.g. `listen_and_pick`.
  final String game;
}
