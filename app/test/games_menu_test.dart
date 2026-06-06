import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/features/games_menu/games_menu_page.dart';
import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/progress_service.dart';

void main() {
  testWidgets('lists games and opens the tapped one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: GamesMenuPage(
        progress: ProgressService(
          bank: const ContentBank(version: '0', elements: [], words: []),
        ),
        games: [
          GameEntry(
            title: 'Alpha',
            subtitle: 'first',
            icon: Icons.star,
            builder: (_) => const Scaffold(body: Center(child: Text('ALPHA SCREEN'))),
          ),
          GameEntry(
            title: 'Beta',
            subtitle: 'second',
            icon: Icons.circle,
            builder: (_) => const Scaffold(body: Center(child: Text('BETA SCREEN'))),
          ),
        ],
      ),
    ));

    // Both games are listed.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Tapping one navigates into it.
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('BETA SCREEN'), findsOneWidget);
  });
}
