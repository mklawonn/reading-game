import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/learning/curriculum_engine.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/models/curriculum.dart';

ContentBank _bank() => const ContentBank(
      version: '0',
      elements: [
        SyllableElement(id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
        SyllableElement(id: 'dog', type: 'pictograph', syllable: 'dog', soundIpa: '', picturable: true),
        SyllableElement(id: 'sun', type: 'pictograph', syllable: 'sun', soundIpa: '', picturable: true),
        SyllableElement(id: 'and', type: 'letter_array', syllable: 'and', soundIpa: '', picturable: false),
      ],
      words: [],
    );

CurriculumSchedule _schedule() => const CurriculumSchedule(
      version: '0',
      levels: [
        CurriculumLevel(id: 1, stage: 1, title: 'A', introduce: ['cat', 'dog'], games: ['find_the_character'], xpToAdvance: 40),
        CurriculumLevel(id: 2, stage: 1, title: 'B', introduce: ['sun'], games: ['sound_match', 'families'], xpToAdvance: 40),
        CurriculumLevel(id: 3, stage: 2, title: 'C', introduce: ['and'], games: ['build_a_word'], xpToAdvance: 50),
      ],
    );

void main() {
  late CurriculumEngine engine;
  setUp(() => engine = CurriculumEngine(schedule: _schedule(), bank: _bank(), random: Random(1)));

  test('introducedThrough accumulates symbols level by level', () {
    expect(engine.introducedThrough(1), {'cat', 'dog'});
    expect(engine.introducedThrough(2), {'cat', 'dog', 'sun'});
    expect(engine.introducedThrough(3), {'cat', 'dog', 'sun', 'and'});
  });

  test('a level introduces its symbols (Meet card) before any game', () {
    final first = engine.next(1, const {});
    expect(first, isA<IntroduceActivity>());
    expect((first as IntroduceActivity).symbolId, 'cat');

    expect(engine.pendingIntros(1, const {'cat'}), ['dog']);

    final afterIntros = engine.next(1, const {'cat', 'dog'});
    expect(afterIntros, isA<GameActivity>());
    expect((afterIntros as GameActivity).gameId, 'find_the_character');
  });

  test('scoped pool contains only introduced picturables (no stage-skipping)', () {
    expect(engine.scopedPool(1).map((e) => e.id).toSet(), {'cat', 'dog'});
    // sun is not introduced until level 2...
    expect(engine.scopedPool(1).any((e) => e.id == 'sun'), isFalse);
    expect(engine.scopedPool(2).map((e) => e.id).toSet(), {'cat', 'dog', 'sun'});
    // ...and 'and' is never picturable, so never in the pool.
    expect(engine.scopedPool(3).any((e) => e.id == 'and'), isFalse);
  });

  test('a level only ever yields a game from its own list', () {
    for (var k = 0; k < 30; k++) {
      final a = engine.next(2, const {'cat', 'dog', 'sun'});
      expect((a as GameActivity).gameId, anyOf('sound_match', 'families'));
    }
  });
}
