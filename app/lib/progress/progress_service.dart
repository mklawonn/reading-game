import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/content_bank.dart';
import 'achievements.dart';
import 'learning_event.dart';

/// Leitner-box mastery for a single item.
@immutable
class ItemMastery {
  const ItemMastery({this.box = 0, this.correct = 0, this.seen = 0});

  static const int masteredBox = 4; // boxes 0..5; mastered at >= 4

  final int box;
  final int correct;
  final int seen;

  bool get mastered => box >= masteredBox;

  ItemMastery promote() =>
      ItemMastery(box: min(5, box + 1), correct: correct + 1, seen: seen + 1);
  ItemMastery demote() =>
      ItemMastery(box: max(0, box - 1), correct: correct, seen: seen + 1);

  Map<String, dynamic> toJson() => {'box': box, 'correct': correct, 'seen': seen};
  factory ItemMastery.fromJson(Map<String, dynamic> j) => ItemMastery(
        box: j['box'] as int? ?? 0,
        correct: j['correct'] as int? ?? 0,
        seen: j['seen'] as int? ?? 0,
      );
}

/// The content-agnostic progression engine. It consumes [LearningEvent]s and
/// exposes XP/level, per-item mastery, a daily streak, per-stage progress and
/// unlocked achievements. It knows the curriculum only as data (stage totals
/// derived from the Content Bank), so content changes don't ripple into it.
class ProgressService extends ChangeNotifier {
  ProgressService({required ContentBank bank, DateTime Function()? clock})
      : _itemStage = {for (final e in bank.elements) e.id: e.introducedStage},
        _stageTotals = _countByStage(bank),
        _now = clock ?? DateTime.now;

  static const int xpPerCorrect = 10;
  static const int xpMasteryBonus = 25;

  final Map<String, int> _itemStage;
  final Map<int, int> _stageTotals;
  final DateTime Function() _now;

  int _xp = 0;
  final Map<String, ItemMastery> _mastery = {};
  final Map<String, int> _skillCorrect = {};
  int _totalCorrect = 0;
  int _totalAnswered = 0;
  int _run = 0; // current consecutive-correct run
  int _bestRun = 0;
  int _dayStreak = 0;
  String? _lastDay;
  final Set<String> _unlocked = {};
  final List<Achievement> _justUnlocked = [];

  static Map<int, int> _countByStage(ContentBank bank) {
    final m = <int, int>{};
    for (final e in bank.elements) {
      m[e.introducedStage] = (m[e.introducedStage] ?? 0) + 1;
    }
    return m;
  }

  // ── read-only views (UI + achievement predicates) ──
  int get xp => _xp;
  int get level => levelForXp(_xp);
  int get xpIntoLevel => _xp - xpForLevel(level);
  int get xpForThisLevel => xpForLevel(level + 1) - xpForLevel(level);
  int get masteredCount => _mastery.values.where((m) => m.mastered).length;
  int get totalCorrect => _totalCorrect;
  int get totalAnswered => _totalAnswered;
  int get bestRun => _bestRun;
  int get dayStreak => _dayStreak;
  int skillCorrect(String skill) => _skillCorrect[skill] ?? 0;
  List<int> get stages => _stageTotals.keys.toList()..sort();
  bool isUnlocked(String id) => _unlocked.contains(id);

  /// Fraction (0..1) of a stage's elements that are mastered.
  double stageProgress(int stage) {
    final total = _stageTotals[stage] ?? 0;
    if (total == 0) return 0;
    var mastered = 0;
    _mastery.forEach((id, m) {
      if (m.mastered && _itemStage[id] == stage) mastered++;
    });
    return mastered / total;
  }

  /// Achievements unlocked since the last call (for a toast); clears the queue.
  List<Achievement> takeJustUnlocked() {
    final out = List<Achievement>.from(_justUnlocked);
    _justUnlocked.clear();
    return out;
  }

  // ── the single mutation ──
  void record(LearningEvent e) {
    _totalAnswered++;
    final prev = _mastery[e.itemId] ?? const ItemMastery();
    if (e.correct) {
      _totalCorrect++;
      _run++;
      _bestRun = max(_bestRun, _run);
      _skillCorrect[e.skill] = (_skillCorrect[e.skill] ?? 0) + 1;
      final next = prev.promote();
      _mastery[e.itemId] = next;
      _xp += xpPerCorrect;
      if (!prev.mastered && next.mastered) _xp += xpMasteryBonus;
    } else {
      _run = 0;
      _mastery[e.itemId] = prev.demote();
    }
    _touchStreak();
    _checkAchievements();
    notifyListeners();
  }

  void _touchStreak() {
    final now = _now();
    final today = _ymd(now);
    if (_lastDay == today) return;
    final yesterday = _ymd(now.subtract(const Duration(days: 1)));
    _dayStreak = (_lastDay == yesterday) ? _dayStreak + 1 : 1;
    _lastDay = today;
  }

  void _checkAchievements() {
    for (final a in kAchievements) {
      if (!_unlocked.contains(a.id) && a.test(this)) {
        _unlocked.add(a.id);
        _justUnlocked.add(a);
      }
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── XP curve: cumulative XP to reach level n is 50*n*(n-1) ──
  static int xpForLevel(int level) => 50 * level * (level - 1);
  static int levelForXp(int xp) {
    var n = 1;
    while (xpForLevel(n + 1) <= xp) {
      n++;
    }
    return n;
  }

  // ── persistence (in-memory now; Firestore-ready) ──
  Map<String, dynamic> toJson() => {
        'xp': _xp,
        'mastery': {for (final e in _mastery.entries) e.key: e.value.toJson()},
        'skillCorrect': _skillCorrect,
        'totalCorrect': _totalCorrect,
        'totalAnswered': _totalAnswered,
        'bestRun': _bestRun,
        'dayStreak': _dayStreak,
        'lastDay': _lastDay,
        'unlocked': _unlocked.toList(),
      };

  void loadJson(Map<String, dynamic> j) {
    _xp = j['xp'] as int? ?? 0;
    _mastery
      ..clear()
      ..addAll((j['mastery'] as Map<String, dynamic>? ?? {}).map((k, v) =>
          MapEntry(k, ItemMastery.fromJson(v as Map<String, dynamic>))));
    _skillCorrect
      ..clear()
      ..addAll((j['skillCorrect'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)));
    _totalCorrect = j['totalCorrect'] as int? ?? 0;
    _totalAnswered = j['totalAnswered'] as int? ?? 0;
    _bestRun = j['bestRun'] as int? ?? 0;
    _dayStreak = j['dayStreak'] as int? ?? 0;
    _lastDay = j['lastDay'] as String?;
    _unlocked
      ..clear()
      ..addAll((j['unlocked'] as List<dynamic>? ?? const []).cast<String>());
    notifyListeners();
  }
}
