import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/content/glyph_view.dart';
import 'package:reading_game/content/syllable_tile.dart';
import 'package:reading_game/models/content_bank.dart';

void main() {
  testWidgets('art-first: picturable element renders an Image (the drop-in slot)',
      (tester) async {
    const cat = SyllableElement(
      id: 'cat',
      type: 'pictograph',
      syllable: 'cat',
      soundIpa: '',
      picturable: true,
      imageRef: 'cat.png',
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: GlyphView(cat)))),
    );
    // GlyphView reaches for the real art first (falls back to emoji if absent).
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('non-picturable syllable renders as linked letters (SyllableTile)',
      (tester) async {
    const and = SyllableElement(
      id: 'and',
      type: 'letter_array',
      syllable: 'and',
      soundIpa: '',
      picturable: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: GlyphView(and)))),
    );
    expect(find.byType(SyllableTile), findsOneWidget);
    expect(find.text('and'), findsOneWidget);
  });
}
