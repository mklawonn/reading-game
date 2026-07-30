import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/curriculum.dart';
import 'package:reading_game/progress/learning_event.dart';
import 'package:reading_game/progress/progress_service.dart';

ContentBank _bank() => const ContentBank(
      version: '0',
      elements: [
        SyllableElement(id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
      ],
      words: [],
    );

CurriculumSchedule _schedule() => const CurriculumSchedule(
      version: '0',
      levels: [
        CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat'], games: ['find_the_character'], xpToAdvance: 20, lessons: 2),
        CurriculumLevel(id: 2, stage: 2, title: 'B', introduce: ['dog'], games: ['sound_match'], xpToAdvance: 30, lessons: 1),
      ],
    );

LearningEvent _correct() =>
    const LearningEvent(itemId: 'cat', skill: 'recognize', stage: 1, correct: true, game: 'g');

void main() {
  test('lessons fill the level, roll over, and queue the level-up', () {
    final p = ProgressService(bank: _bank(), schedule: _schedule());
    expect(p.level, 1);
    expect(p.lessonsForThisLevel, 2);

    p.completeLesson();
    expect(p.level, 1);
    expect(p.lessonsIntoLevel, 1);
    expect(p.levelFraction, 0.5);

    p.completeLesson(); // 2/2 → level 2
    expect(p.level, 2);
    expect(p.lessonsIntoLevel, 0);
    expect(p.takeJustLeveledUp(), [2]);
    expect(p.takeJustLeveledUp(), isEmpty); // consumed
    expect(p.curriculumStage, 2); // the new level's stage

    // The final level caps full instead of overflowing.
    p.completeLesson();
    p.completeLesson();
    expect(p.level, 2);
    expect(p.lessonsIntoLevel, 1);
    expect(p.pathComplete, isTrue);
  });

  test('answers grant XP but never advance the curriculum level', () {
    final p = ProgressService(bank: _bank(), schedule: _schedule());
    for (var i = 0; i < 10; i++) {
      p.record(_correct());
    }
    expect(p.xp, greaterThan(0));
    expect(p.level, 1); // only completeLesson moves the level
  });

  test('curriculum level + seen intros persist through toJson/loadJson', () {
    final p = ProgressService(bank: _bank(), schedule: _schedule());
    p.markIntroSeen('cat');
    p.record(_correct());
    p.completeLesson();
    p.completeLesson(); // → level 2

    final p2 = ProgressService(bank: _bank(), schedule: _schedule());
    p2.loadJson(p.toJson());
    expect(p2.level, 2);
    expect(p2.hasSeenIntro('cat'), isTrue);

    // Mid-level lesson progress survives a restart too.
    final p3 = ProgressService(bank: _bank(), schedule: _schedule());
    p3.completeLesson();
    final p4 = ProgressService(bank: _bank(), schedule: _schedule());
    p4.loadJson(p3.toJson());
    expect(p4.lessonsIntoLevel, 1);
  });

  test('without a schedule, level falls back to the XP curve', () {
    final p = ProgressService(bank: _bank()); // no schedule
    p.loadJson({'xp': 320});
    expect(p.level, 3);
  });
}
