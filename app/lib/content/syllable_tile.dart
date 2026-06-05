import 'package:flutter/material.dart';

/// Renders a syllable spelled with letters as a single **linked** unit: the
/// letters are tightly set and bound by one continuous underline bar, so a
/// multi-letter syllable (`and`, `ing`, `for`) reads as one whole sound-piece
/// rather than as separate letters. (Separated letters are reserved for the
/// alphabet stage — keeping them joined here signals "this is one chunk".)
class SyllableTile extends StatelessWidget {
  const SyllableTile(this.syllable, {super.key, this.fontSize = 26, this.color});

  final String syllable;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = color ?? scheme.onSecondaryContainer;
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            syllable,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5, // pull the letters together
              color: ink,
            ),
          ),
          SizedBox(height: fontSize * 0.12),
          // The continuous bar is the "link" binding the letters into one piece.
          Container(
            height: fontSize * 0.14,
            decoration: BoxDecoration(
              color: ink,
              borderRadius: BorderRadius.circular(fontSize),
            ),
          ),
        ],
      ),
    );
  }
}
