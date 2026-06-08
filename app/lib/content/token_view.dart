import 'package:flutter/material.dart';

import '../models/content_bank.dart';
import 'glyph_view.dart';
import 'syllable_tile.dart';

/// Renders one phrase token in the orthography of the child's current [stage]:
///
///  * **Stage 1** — a picture for picturable elements (pictograph art/emoji);
///  * **Stage 2+** — the syllable as linked letters.
///
/// This single switch is what lets one authored phrase repeat across stages —
/// pictographs early, letters later — without re-authoring the content.
class TokenView extends StatelessWidget {
  const TokenView(
    this.element, {
    super.key,
    required this.stage,
    this.size = 44,
    this.onTap,
  });

  final SyllableElement element;
  final int stage;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final asPicture = stage <= 1 && element.picturable;
    final Widget glyph = asPicture
        ? GlyphView(element, size: size)
        : SyllableTile(element.syllable, fontSize: size * 0.5);
    if (onTap == null) return glyph;
    return GestureDetector(onTap: onTap, child: glyph);
  }
}
