import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/learning/lesson_plan.dart';
import 'package:reading_game/models/curriculum.dart';

CurriculumLevel _level({
  List<String> introduce = const [],
  List<String> games = const ['find_the_character'],
  int lessons = 3,
  bool story = false,
}) =>
    CurriculumLevel(
        id: 1,
        stage: 1,
        title: 'T',
        introduce: introduce,
        games: games,
        xpToAdvance: 50,
        lessons: lessons,
        story: story);

void main() {
  test('meet lesson: each new symbol is taught then drilled in an escalating block', () {
    final steps = LessonPlan.build(
      level: _level(
          introduce: ['cat', 'dog'],
          games: ['find_the_character', 'symbol_hunt', 'listen_and_pick']),
      seenIntros: const {},
      random: Random(1),
    );

    // Intro cat → three drills on cat, ear-first and print-last.
    expect(steps[0], isA<IntroStep>().having((s) => s.symbolId, 'symbol', 'cat'));
    expect(
        steps.sublist(1, 4),
        everyElement(
            isA<ExerciseStep>().having((s) => s.focusId, 'focus', 'cat')));
    expect(
        [for (final s in steps.sublist(1, 4)) (s as ExerciseStep).gameId],
        ['listen_and_pick', 'symbol_hunt', 'find_the_character']);
    // Then the same treatment for dog.
    expect(steps[4], isA<IntroStep>().having((s) => s.symbolId, 'symbol', 'dog'));
    expect(
        steps.sublist(5, 8),
        everyElement(
            isA<ExerciseStep>().having((s) => s.focusId, 'focus', 'dog')));
  });

  test('meeting three or more symbols shortens each drill block to two', () {
    final steps = LessonPlan.build(
      level: _level(
          introduce: ['a', 'b', 'c'],
          games: ['listen_and_pick', 'symbol_hunt', 'find_the_character']),
      seenIntros: const {},
      random: Random(1),
    );
    expect(steps.whereType<IntroStep>().length, 3);
    expect(steps.whereType<ExerciseStep>().length, 6); // 3 × 2
  });

  test('middle lessons are sounds-themed and open with the level symbols', () {
    final steps = LessonPlan.build(
      level: _level(
          introduce: ['cat', 'dog'],
          games: [
            'find_the_character', 'listen_and_pick', 'sound_match',
            'symbol_hunt', 'picture_to_word',
          ]),
      seenIntros: const {'cat', 'dog'},
      lessonIndex: 1, // middle of a 3-lesson level
      random: Random(2),
    );
    expect(steps.whereType<IntroStep>(), isEmpty);
    final exercises = steps.whereType<ExerciseStep>().toList();
    // Only listening/matching games.
    for (final e in exercises) {
      expect(LessonPlan.soundGames, contains(e.gameId), reason: e.gameId);
    }
    // The level's own symbols come back first (retention).
    expect({exercises[0].focusId, exercises[1].focusId}, {'cat', 'dog'});
  });

  test('the last lesson of a level is reading-themed', () {
    final steps = LessonPlan.build(
      level: _level(
          introduce: ['cat', 'dog'],
          games: [
            'find_the_character', 'listen_and_pick', 'sound_match',
            'picture_to_word', 'echo_read',
          ]),
      seenIntros: const {'cat', 'dog'},
      lessonIndex: 2, // last of 3
      random: Random(3),
    );
    for (final e in steps.whereType<ExerciseStep>()) {
      expect(LessonPlan.readingGames, contains(e.gameId), reason: e.gameId);
    }
  });

  test('a theme that cannot fill falls back to the whole game list', () {
    final steps = LessonPlan.build(
      level: _level(
          introduce: ['cat'],
          games: ['find_the_character', 'listen_and_pick']),
      seenIntros: const {'cat'},
      lessonIndex: 1, // sounds theme, but only one sound game available
      random: Random(4),
    );
    final ids = steps.whereType<ExerciseStep>().map((s) => s.gameId).toSet();
    expect(ids, containsAll(['find_the_character', 'listen_and_pick']));
  });

  test('games vary — never the same type twice in a row when avoidable', () {
    final steps = LessonPlan.build(
      level: _level(games: ['listen_and_pick', 'sound_match', 'symbol_hunt']),
      seenIntros: const {},
      lessonIndex: 1,
      random: Random(7),
    );
    final ids = steps.whereType<ExerciseStep>().map((s) => s.gameId).toList();
    for (var i = 1; i < ids.length; i++) {
      expect(ids[i], isNot(ids[i - 1]), reason: 'repeat at $i in $ids');
    }
  });

  test('a story level devotes its second-to-last node entirely to Story Time', () {
    final level = _level(
        introduce: ['cat'],
        games: ['listen_and_pick', 'find_the_character'],
        lessons: 4,
        story: true);
    expect(
        LessonPlan.themeFor(
            level: level, seenIntros: const {'cat'}, lessonIndex: 2),
        LessonTheme.story);
    final steps = LessonPlan.build(
      level: level,
      seenIntros: const {'cat'},
      lessonIndex: 2,
      random: Random(5),
    );
    expect(steps, hasLength(1));
    expect(steps.single,
        isA<ExerciseStep>().having((s) => s.gameId, 'game', 'story_time'));
  });

  test('the four themes land on the right nodes of a 4-lesson level', () {
    final level = _level(
        introduce: ['cat'], games: ['listen_and_pick'], lessons: 4, story: true);
    LessonTheme at(int i, {bool met = true}) => LessonPlan.themeFor(
        level: level, seenIntros: met ? const {'cat'} : const {}, lessonIndex: i);
    expect(at(0, met: false), LessonTheme.meet);
    expect(at(1), LessonTheme.sounds);
    expect(at(2), LessonTheme.story);
    expect(at(3), LessonTheme.reading);
  });

  test('a single-game level still fills a whole (short) lesson', () {
    final steps = LessonPlan.build(
      level: _level(games: ['find_the_character']),
      seenIntros: const {},
      lessonIndex: 2,
      random: Random(2),
    );
    expect(steps, isNotEmpty);
    expect(steps.whereType<ExerciseStep>().length, steps.length);
  });
}
