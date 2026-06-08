import 'dart:math';

import 'mastery_view.dart';

/// Chooses which item a game shows next, so that **progress steers content**
/// instead of blind shuffling. Selection is weighted by two signals:
///
///  * the curriculum **stage mix** ([MasteryView.stageWeights]) — favor the
///    child's current stage, lightly review earlier stages, trickle in the next;
///  * per-item **Leitner box** — focus on weak/unseen items, resurface mastered
///    ones only occasionally (spaced review).
///
/// A **working-set cap** stops brand-new items from flooding in: once enough
/// unmastered items are already in rotation, unseen items are held back until
/// the child consolidates (the paper's i+1 principle).
///
/// The class is plain Dart (no Flutter) and depends only on [MasteryView], so it
/// is fully unit-testable and carries no coupling to specific content.
class ItemSampler {
  ItemSampler(this._mastery, {Random? random}) : _random = random ?? Random();

  final MasteryView _mastery;
  final Random _random;

  // ── Tunables (centralized here; Remote-Config-ready later) ──
  /// Max unmastered items allowed in active rotation before new ones are gated.
  static const int workingSetCap = 6;

  /// Relative weight by Leitner box (index = box 0..5): weak/unseen items get the
  /// most practice; mastered items keep a small review weight, never zero.
  static const List<double> boxWeight = [1.0, 0.9, 0.7, 0.5, 0.25, 0.12];

  /// Weight for a stage the mix doesn't mention (far-future material).
  static const double _dormantStageWeight = 0.02;

  /// Picks one item from [pool], weighted by stage mix × Leitner box.
  ///
  /// [id]/[stage] extract those fields from a pool element; [exclude] avoids
  /// immediately repeating the previous target. Falls back to a uniform pick if
  /// every candidate ends up weightless (e.g. a single, excluded item).
  T pick<T>(
    List<T> pool, {
    required String Function(T) id,
    required int Function(T) stage,
    String? exclude,
  }) {
    if (pool.isEmpty) {
      throw ArgumentError('ItemSampler.pick called with an empty pool');
    }

    final stageW = _mastery.stageWeights();

    // Are enough unmastered items already in flight? If so, gate new material.
    final inProgress = pool
        .where((e) => _mastery.hasSeen(id(e)) && !_mastery.isMastered(id(e)))
        .length;
    final atCap = inProgress >= workingSetCap;

    double weightOf(T item) {
      final itemId = id(item);
      if (itemId == exclude && pool.length > 1) return 0;
      // Hold back brand-new items while the working set is full.
      if (!_mastery.hasSeen(itemId) && atCap) return 0;
      final sw = stageW[stage(item)] ?? _dormantStageWeight;
      final box = _mastery.boxOf(itemId).clamp(0, boxWeight.length - 1);
      return sw * boxWeight[box];
    }

    final weights = [for (final item in pool) weightOf(item)];
    final total = weights.fold(0.0, (a, b) => a + b);
    if (total <= 0) {
      return pool[_random.nextInt(pool.length)];
    }

    var r = _random.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r < 0) return pool[i];
    }
    return pool.last; // floating-point guard
  }
}
