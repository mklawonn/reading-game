import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/progress/progress_service.dart';

ContentBank _bank() => const ContentBank(
      version: '0',
      elements: [
        SyllableElement(
            id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
        SyllableElement(
            id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
        SyllableElement(
            id: 'and', type: 'letter_array', syllable: 'and', soundIpa: '', picturable: false, introducedStage: 2),
      ],
      words: [],
    );

LearningEvent _ev(String id, bool correct,
        {String skill = 'recognize', int stage = 1}) =>
    LearningEvent(itemId: id, skill: skill, stage: stage, correct: correct, game: 'g');

void main() {
  test('correct answers add XP and raise the level', () {
    final p = ProgressService(bank: _bank());
    expect(p.level, 1);
    for (var i = 0; i < 12; i++) {
      p.record(_ev('cat', true));
    }
    expect(p.xp, greaterThanOrEqualTo(120));
    expect(p.level, greaterThanOrEqualTo(2));
    expect(p.totalCorrect, 12);
  });

  test('four corrects master an item; stage progress reflects it', () {
    final p = ProgressService(bank: _bank());
    for (var i = 0; i < 4; i++) {
      p.record(_ev('cat', true));
    }
    expect(p.masteredCount, 1);
    expect(p.stageProgress(1), 0.5); // 1 of 2 Stage-1 elements mastered
  });

  test('a wrong answer breaks the run but keeps the best', () {
    final p = ProgressService(bank: _bank());
    p.record(_ev('cat', true));
    p.record(_ev('cat', true));
    expect(p.bestRun, 2);
    p.record(_ev('cat', false));
    expect(p.bestRun, 2);
  });

  test('achievements unlock from aggregates, not specific content', () {
    final p = ProgressService(bank: _bank());
    expect(p.isUnlocked('first_steps'), isFalse);
    p.record(_ev('cat', true));
    expect(p.isUnlocked('first_steps'), isTrue);

    expect(p.isUnlocked('blender'), isFalse);
    p.record(_ev('open', true, skill: 'blend', stage: 2));
    expect(p.isUnlocked('blender'), isTrue);
  });

  test('daily streak increments across consecutive days', () {
    var day = DateTime(2026, 1, 1, 9);
    final p = ProgressService(bank: _bank(), clock: () => day);
    p.record(_ev('cat', true));
    expect(p.dayStreak, 1);
    p.record(_ev('dog', true)); // same day → unchanged
    expect(p.dayStreak, 1);
    day = DateTime(2026, 1, 2, 9); // next day
    p.record(_ev('cat', true));
    expect(p.dayStreak, 2);
    day = DateTime(2026, 1, 4, 9); // skipped a day → reset
    p.record(_ev('dog', true));
    expect(p.dayStreak, 1);
  });
}
