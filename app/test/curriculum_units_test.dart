import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/models/curriculum.dart';

void main() {
  test('units parse and map levels to their world', () {
    final schedule = CurriculumSchedule.fromJson({
      'version': '3',
      'units': [
        {'id': 1, 'title': 'Home Meadow', 'emoji': '🏡', 'levels': [1, 2]},
        {'id': 2, 'title': 'The Farm', 'emoji': '🌾', 'levels': [3]},
      ],
      'levels': [
        {'id': 1, 'introduce': ['cat'], 'games': ['listen_and_pick'], 'lessons': 4, 'story': true},
        {'id': 2, 'introduce': [], 'games': ['listen_and_pick'], 'lessons': 3},
        {'id': 3, 'introduce': ['pig'], 'games': ['listen_and_pick']},
      ],
    });

    expect(schedule.units, hasLength(2));
    expect(schedule.unitFor(1).title, 'Home Meadow');
    expect(schedule.unitFor(2).emoji, '🏡');
    expect(schedule.unitFor(3).title, 'The Farm');
    expect(schedule.levelAt(1).story, isTrue);
    expect(schedule.levelAt(2).story, isFalse);
    expect(schedule.levelAt(1).lessons, 4);
  });

  test('a schedule without units falls back to one catch-all world', () {
    final schedule = CurriculumSchedule.fromJson({
      'version': '0',
      'levels': [
        {'id': 1, 'introduce': ['cat'], 'games': ['listen_and_pick']},
        {'id': 2, 'introduce': [], 'games': ['listen_and_pick']},
      ],
    });
    final unit = schedule.unitFor(2);
    expect(unit.levels, [1, 2]);
    expect(unit.title, isNotEmpty);
  });
}
