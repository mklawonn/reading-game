import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/learning/item_sampler.dart';
import 'package:reading_game/learning/mastery_view.dart';

/// A pool element with just the fields the sampler reads.
class _Item {
  const _Item(this.id, this.stage);
  final String id;
  final int stage;
}

/// Hand-set learner state for deterministic sampler tests.
class _FakeMastery implements MasteryView {
  _FakeMastery({
    this.boxes = const {},
    this.seen = const {},
    this.mastered = const {},
    this.weights = const {1: 1.0},
  });

  final Map<String, int> boxes;
  final Set<String> seen;
  final Set<String> mastered;
  final Map<int, double> weights;

  @override
  int boxOf(String id) => boxes[id] ?? 0;
  @override
  bool hasSeen(String id) => seen.contains(id);
  @override
  bool isMastered(String id) => mastered.contains(id);
  @override
  Map<int, double> stageWeights() => weights;
}

Map<String, int> _tally(
  ItemSampler sampler,
  List<_Item> pool, {
  int n = 2000,
  String? exclude,
}) {
  final counts = {for (final i in pool) i.id: 0};
  for (var k = 0; k < n; k++) {
    final picked =
        sampler.pick(pool, id: (i) => i.id, stage: (i) => i.stage, exclude: exclude);
    counts[picked.id] = counts[picked.id]! + 1;
  }
  return counts;
}

void main() {
  test('mastered items resurface far less than weak ones', () {
    final mastery = _FakeMastery(
      seen: {'weak', 'strong'},
      boxes: {'weak': 0, 'strong': 5},
      mastered: {'strong'},
      weights: {1: 1.0},
    );
    final sampler = ItemSampler(mastery, random: Random(7));
    final c = _tally(sampler, const [_Item('weak', 1), _Item('strong', 1)]);
    // boxWeight 1.0 vs 0.12 → weak should dominate by a wide margin, but strong
    // still appears (spaced review, never zero).
    expect(c['weak']!, greaterThan(c['strong']! * 3));
    expect(c['strong']!, greaterThan(0));
  });

  test('working-set cap gates brand-new items once rotation is full', () {
    final full = [for (var i = 0; i < ItemSampler.workingSetCap + 1; i++) 'p$i'];
    final mastery = _FakeMastery(
      seen: full.toSet(), // all seen, none mastered → inProgress > cap
      boxes: {for (final id in full) id: 1},
      weights: {1: 1.0},
    );
    final sampler = ItemSampler(mastery, random: Random(1));
    final pool = [
      for (final id in full) _Item(id, 1),
      const _Item('fresh', 1), // unseen
    ];
    final c = _tally(sampler, pool);
    expect(c['fresh'], 0, reason: 'new item held back while working set is full');
  });

  test('brand-new items DO appear when the working set has room', () {
    final mastery = _FakeMastery(
      seen: {'a', 'b'}, // only 2 in progress, below the cap
      boxes: {'a': 1, 'b': 1},
      weights: {1: 1.0},
    );
    final sampler = ItemSampler(mastery, random: Random(3));
    final c = _tally(
        sampler, const [_Item('a', 1), _Item('b', 1), _Item('fresh', 1)]);
    expect(c['fresh']!, greaterThan(0));
  });

  test('items above the current stage are down-weighted', () {
    final mastery = _FakeMastery(
      seen: {'now', 'future'},
      boxes: {'now': 0, 'future': 0},
      weights: {1: 0.8, 3: 0.02}, // current-stage mix
    );
    final sampler = ItemSampler(mastery, random: Random(5));
    final c = _tally(sampler, const [_Item('now', 1), _Item('future', 3)]);
    expect(c['now']!, greaterThan(c['future']! * 5));
  });

  test('exclude prevents an immediate repeat', () {
    final mastery = _FakeMastery(seen: {'a', 'b'}, weights: {1: 1.0});
    final sampler = ItemSampler(mastery, random: Random(9));
    for (var k = 0; k < 50; k++) {
      final picked = sampler.pick(
        const [_Item('a', 1), _Item('b', 1)],
        id: (i) => i.id,
        stage: (i) => i.stage,
        exclude: 'a',
      );
      expect(picked.id, 'b');
    }
  });

  test('single excluded item falls back to itself (no crash)', () {
    final sampler = ItemSampler(_FakeMastery(), random: Random(0));
    final picked = sampler.pick(
      const [_Item('only', 1)],
      id: (i) => i.id,
      stage: (i) => i.stage,
      exclude: 'only',
    );
    expect(picked.id, 'only');
  });
}
