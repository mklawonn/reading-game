import 'package:flutter/material.dart';

/// The big "next" control pinned at the bottom of every activity.
///
/// It is **always present** (so the board never jumps when a round is solved)
/// but only becomes tappable once [enabled] is true — i.e. after the child has
/// completed the task. A small child can mash it freely and only advance when
/// they've actually finished. Full-width and tall so little fingers can't miss.
class NextArrowBar extends StatelessWidget {
  const NextArrowBar({super.key, required this.enabled, required this.onNext});

  /// Whether the current activity is finished (the arrow is tappable).
  final bool enabled;

  /// Advance to the next round/activity.
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 68,
        width: double.infinity,
        child: FilledButton(
          // A null callback disables the button — it dims via the theme and
          // ignores taps until the round is solved.
          onPressed: enabled ? onNext : null,
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Icon(Icons.arrow_forward_rounded, size: 40),
        ),
      ),
    );
  }
}
