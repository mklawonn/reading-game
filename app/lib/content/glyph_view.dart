import 'package:flutter/material.dart';

import '../models/content_bank.dart';
import 'pictograph_emoji.dart';
import 'syllable_tile.dart';

/// Renders a Content Bank [SyllableElement] as its symbol, **art-first**:
///   1. a real pictograph image (`assets/images/pictographs/<id>.png`) if bundled,
///   2. else an emoji stand-in ([kPictographEmoji]),
///   3. else the syllable as linked letters ([SyllableTile]).
///
/// This is the drop-in point for the art pipeline: add a PNG to the folder and
/// it appears automatically; until then the emoji (or letter tile) shows.
class GlyphView extends StatelessWidget {
  const GlyphView(this.element, {super.key, this.size = 64});

  final SyllableElement element;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (element.picturable) {
      final assetPath =
          'assets/images/pictographs/${element.imageRef ?? '${element.id}.png'}';
      return Image.asset(
        assetPath,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final emoji = kPictographEmoji[element.id];
    if (emoji != null) {
      return Text(emoji, style: TextStyle(fontSize: size * 0.82));
    }
    return SyllableTile(element.syllable, fontSize: size * 0.42);
  }
}
