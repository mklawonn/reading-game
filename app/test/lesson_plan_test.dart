import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/learning/lesson_plan.dart';
import 'package:reading_game/models/curriculum.dart';

CurriculumLevel _level({List<String> introduce = const [], List<String> games = const ['find_the_character']}) =>
    CurriculumLevel(id: 1, stage: 1, title: 'T', introduce: introduce, games: games, xpToAdvance: 50);

void main() {
  test('every unmet symbol gets an intro chased by a focused exercise', () {
    final steps = LessonPlan.build(
      level: _level(introduce: ['cat', 'dog'], games: ['listen_and_pick', 'sound_match']),
      seenIntros: const {},
      random: Random(1),
    );

    expect(steps[0], isA<IntroStep>().having((s) => s.symbolId, 'symbol', 'cat'));
    expect(
        steps[1],
        isA<ExerciseStep>()
            .having((s) => s.focusId, 'focus', 'cat')
            .having((s) => s.gameId, 'game', 'listen_and_pick'));
    expect(steps[2], isA<IntroStep>().having((s) => s.symbolId, 'symbol', 'dog'));
    expect(steps[3], isA<ExerciseStep>().having((s) => s.focusId, 'focus', 'dog'));
  });

  test('already-met symbols are skipped and the lesson is pure exercises', () {
    final steps = LessonPlan.build(
      level: _level(introduce: ['cat'], games: ['listen_and_pick', 'sound_match', 'symbol_hunt']),
      seenIntros: const {'cat'},
      random: Random(1),
    );
    expect(steps.whereType<IntroStep>(), isEmpty);
    expect(steps.length, LessonPlan.defaultExerciseCount);
  });

  test('low-variety levels get shorter lessons', () {
    final steps = LessonPlan.build(
      level: _level(games: ['listen_and_pick', 'sound_match']),
      seenIntros: const {},
      random: Random(1),
    );
    expect(steps.length, LessonPlan.defaultExerciseCount - 2);
  });

  test('games vary — never the same type twice in a row', () {
    final steps = LessonPlan.build(
      level: _level(games: ['a', 'b', 'c']),
      seenIntros: const {},
      random: Random(7),
    );
    final ids = steps.whereType<ExerciseStep>().map((s) => s.gameId).toList();
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i], isNot(ids[i - 1]), reason: 'repeat at $i in $ids');
    }
  });

  test('a single-game level still fills a whole (short) lesson', () {
    final steps = LessonPlan.build(
      level: _level(games: ['find_the_character']),
      seenIntros: const {},
      random: Random(2),
    );
    expect(steps.length, LessonPlan.defaultExerciseCount - 2);
    expect(steps.whereType<ExerciseStep>().length, steps.length);
  });

  test('total exercise count stays at the lesson size with intros present', () {
    final steps = LessonPlan.build(
      level: _level(introduce: ['cat', 'dog'], games: ['a', 'b', 'c']),
      seenIntros: const {},
      random: Random(3),
    );
    expect(steps.whereType<IntroStep>().length, 2);
    expect(steps.whereType<ExerciseStep>().length,
        LessonPlan.defaultExerciseCount);
  });
}
