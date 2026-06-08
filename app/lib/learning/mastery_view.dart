/// The narrow, Flutter-free view of learner state that the [ItemSampler] needs.
///
/// Keeping this interface tiny (rather than handing the sampler the whole
/// `ProgressService`) is what keeps content selection **decoupled** from the
/// progression engine and trivially unit-testable with a fake. `ProgressService`
/// implements it; tests provide their own.
abstract interface class MasteryView {
  /// Leitner box (0..5) for [itemId]; 0 if never seen.
  int boxOf(String itemId);

  /// Whether [itemId] has been answered at least once.
  bool hasSeen(String itemId);

  /// Whether [itemId] has reached the mastered box.
  bool isMastered(String itemId);

  /// Sampling weight per curriculum stage — the curriculum's gradual
  /// "center of gravity" mix (peaked at the child's current stage, with review
  /// weight to earlier stages and a little intro weight to the next one).
  Map<int, double> stageWeights();
}
