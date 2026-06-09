import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../learning/mastery_view.dart';
import '../models/content_bank.dart';
import '../models/curriculum.dart';
import 'achievements.dart';
import 'learning_event.dart';
import 'progress_store.dart';

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
class ProgressService extends ChangeNotifier implements MasteryView {
  ProgressService({
    required ContentBank bank,
    DateTime Function()? clock,
    ProgressStore store = const NoopProgressStore(),
    String profileId = 'default',
    CurriculumSchedule? schedule,
  })  : _itemStage = {for (final e in bank.elements) e.id: e.introducedStage},
        _stageTotals = _countByStage(bank),
        _now = clock ?? DateTime.now,
        // Named params can't be private initializing formals, so assign here.
        // ignore: prefer_initializing_formals
        _store = store,
        // ignore: prefer_initializing_formals
        _profileId = profileId,
        // ignore: prefer_initializing_formals
        _schedule = schedule;

  static const int xpPerCorrect = 10;
  static const int xpMasteryBonus = 25;

  // Stage-mix tunables — the curriculum "center of gravity". Constants now,
  // Remote-Config-ready later (see docs/curriculum.md).
  static const double _stageAdvanceCoverage = 0.6; // mastered-fraction to advance
  static const double _focusStageWeight = 0.60;
  static const double _reviewStageWeight = 0.15;
  static const double _introStageWeight = 0.10;
  static const double _dormantStageWeight = 0.02;

  final Map<String, int> _itemStage;
  final Map<int, int> _stageTotals;
  final DateTime Function() _now;
  final ProgressStore _store;
  final String _profileId;
  final CurriculumSchedule? _schedule;
  Timer? _saveTimer;

  int _xp = 0;
  int _curriculumLevel = 1;
  int _xpIntoLevel = 0;
  final Set<String> _seenIntros = {};
  final List<int> _justLeveledUp = [];
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

  /// The player's level. With a [CurriculumSchedule] this is the **curriculum
  /// level** (advanced by per-level XP goals); without one it falls back to the
  /// generic XP curve (keeps schedule-free tests/usages working).
  int get level => _schedule != null ? _curriculumLevel : levelForXp(_xp);
  int get xpIntoLevel =>
      _schedule != null ? _xpIntoLevel : _xp - xpForLevel(level);
  int get xpForThisLevel => _schedule != null
      ? _schedule.levelAt(_curriculumLevel).xpToAdvance
      : xpForLevel(level + 1) - xpForLevel(level);

  /// Total number of levels in the schedule (0 if none).
  int get totalLevels => _schedule?.length ?? 0;

  /// The current level's nominal stage (for current-stage rendering); falls back
  /// to the mastery-derived [currentStage] when no schedule is set.
  int get curriculumStage =>
      _schedule != null ? _schedule.levelAt(_curriculumLevel).stage : currentStage;

  // ── curriculum intros + level-ups ──
  Set<String> get seenIntros => Set.unmodifiable(_seenIntros);
  bool hasSeenIntro(String id) => _seenIntros.contains(id);
  void markIntroSeen(String id) {
    if (_seenIntros.add(id)) {
      notifyListeners();
      _scheduleSave();
    }
  }

  /// Levels reached since the last call — consumed by the level-up animation.
  List<int> takeJustLeveledUp() {
    final out = List<int>.from(_justLeveledUp);
    _justLeveledUp.clear();
    return out;
  }
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

  // ── MasteryView: the read-only inputs the ItemSampler uses to steer content ──
  @override
  int boxOf(String itemId) => (_mastery[itemId] ?? const ItemMastery()).box;
  @override
  bool hasSeen(String itemId) => (_mastery[itemId]?.seen ?? 0) > 0;
  @override
  bool isMastered(String itemId) => _mastery[itemId]?.mastered ?? false;

  /// The stage the child is actively working in: the lowest stage not yet
  /// covered to [_stageAdvanceCoverage] mastered, else the highest available
  /// stage. This is the peak of the stage mix below, and it advances as coverage
  /// grows — the curriculum's gradual shift, not a switch.
  int get currentStage {
    final ss = stages;
    if (ss.isEmpty) return 1;
    for (final s in ss) {
      if (stageProgress(s) < _stageAdvanceCoverage) return s;
    }
    return ss.last;
  }

  /// The center-of-gravity mix as normalized per-stage weights: peaked at
  /// [currentStage], review weight to earlier stages, a little intro weight to
  /// the next. (≈ the docs' 90/10 → 20/80 ramp as the peak advances.)
  @override
  Map<int, double> stageWeights() {
    final cs = currentStage;
    final raw = <int, double>{};
    for (final s in stages) {
      raw[s] = s < cs
          ? _reviewStageWeight
          : s == cs
              ? _focusStageWeight
              : s == cs + 1
                  ? _introStageWeight
                  : _dormantStageWeight;
    }
    final sum = raw.values.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return {for (final s in stages) s: 1.0};
    return {for (final e in raw.entries) e.key: e.value / sum};
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
    var gained = 0;
    if (e.correct) {
      _totalCorrect++;
      _run++;
      _bestRun = max(_bestRun, _run);
      _skillCorrect[e.skill] = (_skillCorrect[e.skill] ?? 0) + 1;
      final next = prev.promote();
      _mastery[e.itemId] = next;
      gained = xpPerCorrect;
      if (!prev.mastered && next.mastered) gained += xpMasteryBonus;
      _xp += gained;
    } else {
      _run = 0;
      _mastery[e.itemId] = prev.demote();
    }
    if (gained > 0) _advanceLevels(gained);
    _touchStreak();
    _checkAchievements();
    notifyListeners();
    _scheduleSave();
  }

  /// Fills the current level's XP bar and rolls over to the next level(s) once
  /// the schedule's goal is met (queuing each for the level-up animation).
  void _advanceLevels(int gained) {
    final schedule = _schedule;
    if (schedule == null) return;
    _xpIntoLevel += gained;
    while (_curriculumLevel < schedule.length) {
      final need = schedule.levelAt(_curriculumLevel).xpToAdvance;
      if (_xpIntoLevel < need) break;
      _xpIntoLevel -= need;
      _curriculumLevel++;
      _justLeveledUp.add(_curriculumLevel);
    }
    // At the final level the bar simply caps full.
    final cap = schedule.levelAt(_curriculumLevel).xpToAdvance;
    if (_curriculumLevel >= schedule.length && _xpIntoLevel > cap) {
      _xpIntoLevel = cap;
    }
  }

  /// Loads saved progress from the store (call once after construction).
  Future<void> restore() async {
    final data = await _store.load(_profileId);
    if (data != null) loadJson(data);
  }

  void _scheduleSave() {
    if (_store is NoopProgressStore) return; // nothing to persist (e.g. tests)
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), flush);
  }

  /// Writes current progress to the store now (e.g. on app pause).
  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_store is NoopProgressStore) return;
    await _store.save(_profileId, toJson());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
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
        'curriculumLevel': _curriculumLevel,
        'xpIntoLevel': _xpIntoLevel,
        'seenIntros': _seenIntros.toList(),
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
    _curriculumLevel = j['curriculumLevel'] as int? ?? 1;
    _xpIntoLevel = j['xpIntoLevel'] as int? ?? 0;
    _seenIntros
      ..clear()
      ..addAll((j['seenIntros'] as List<dynamic>? ?? const []).cast<String>());
    notifyListeners();
  }
}
