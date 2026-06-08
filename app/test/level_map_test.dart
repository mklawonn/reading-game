import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/progress/level_map_screen.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/progress_service.dart';

ProgressService _progressAtXp(int xp) {
  final p = ProgressService(
    bank: const ContentBank(
      version: '0',
      elements: [
        SyllableElement(
            id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
      ],
      words: [],
    ),
  );
  p.loadJson({'xp': xp});
  return p;
}

void main() {
  testWidgets('level map marks done/current/locked nodes from XP', (tester) async {
    final progress = _progressAtXp(320); // levelForXp(320) == 3

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LevelMap(progress: progress)),
    ));
    await tester.pumpAndSettle();

    expect(progress.level, 3);
    // Current node shows its number...
    expect(find.text('3'), findsOneWidget);
    // ...earlier levels are completed (stars)...
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    // ...and future levels are locked.
    expect(find.byIcon(Icons.lock), findsWidgets);
  });

  testWidgets('a fresh profile sits on level 1', (tester) async {
    final progress = _progressAtXp(0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LevelMap(progress: progress)),
    ));
    await tester.pumpAndSettle();

    expect(progress.level, 1);
    expect(find.text('1'), findsOneWidget); // current node
    expect(find.byIcon(Icons.star), findsNothing); // nothing completed yet
  });
}
