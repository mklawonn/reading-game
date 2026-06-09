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
        CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat'], games: ['find_the_character'], xpToAdvance: 20),
        CurriculumLevel(id: 2, stage: 2, title: 'B', introduce: ['dog'], games: ['sound_match'], xpToAdvance: 30),
      ],
    );

LearningEvent _correct() =>
    const LearningEvent(itemId: 'cat', skill: 'recognize', stage: 1, correct: true, game: 'g');

void main() {
  test('XP fills the level, rolls over, and queues the level-up', () {
    final p = ProgressService(bank: _bank(), schedule: _schedule());
    expect(p.level, 1);
    expect(p.xpForThisLevel, 20);

    p.record(_correct()); // +10
    expect(p.level, 1);
    expect(p.xpIntoLevel, 10);

    p.record(_correct()); // +10 → 20 = goal → level 2
    expect(p.level, 2);
    expect(p.xpIntoLevel, 0);
    expect(p.takeJustLeveledUp(), [2]);
    expect(p.takeJustLeveledUp(), isEmpty); // consumed
    expect(p.curriculumStage, 2); // the new level's stage
    expect(p.xpForThisLevel, 30);
  });

  test('curriculum level + seen intros persist through toJson/loadJson', () {
    final p = ProgressService(bank: _bank(), schedule: _schedule());
    p.markIntroSeen('cat');
    p.record(_correct());
    p.record(_correct()); // → level 2

    final p2 = ProgressService(bank: _bank(), schedule: _schedule());
    p2.loadJson(p.toJson());
    expect(p2.level, 2);
    expect(p2.hasSeenIntro('cat'), isTrue);
  });

  test('without a schedule, level falls back to the XP curve', () {
    final p = ProgressService(bank: _bank()); // no schedule
    p.loadJson({'xp': 320});
    expect(p.level, 3);
  });
}
