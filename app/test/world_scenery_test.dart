import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/home/world_scenery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every shipped world has a theme and generated horizon art', () async {
    final raw = await rootBundle.loadString('assets/content/curriculum.v1.json');
    final units =
        (json.decode(raw) as Map<String, dynamic>)['units'] as List<dynamic>;
    expect(units, isNotEmpty);
    for (final u in units) {
      final id = (u as Map<String, dynamic>)['id'] as int;
      expect(kWorldThemes.containsKey(id), isTrue,
          reason: 'unit $id needs a WorldTheme');
      // The generated art must be bundled (gen-world-art.py output).
      final art = await rootBundle.load('assets/images/worlds/$id.png');
      expect(art.lengthInBytes, greaterThan(0), reason: 'unit $id art');
    }
  });

  test('an unknown world falls back to a safe default theme', () {
    expect(worldThemeFor(999).sky, isNotEmpty);
  });
}
