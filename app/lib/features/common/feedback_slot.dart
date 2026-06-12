import 'package:flutter/material.dart';

/// A fixed-height area for round feedback ("🎉 Yes! / Next", "try again").
///
/// Games show feedback by *inserting* widgets mid-column, which shoves the
/// answer grid/chips around right when the child is about to tap — jarring on
/// small fingers. Reserving the space keeps every target exactly where it was.
class FeedbackSlot extends StatelessWidget {
  const FeedbackSlot({super.key, this.height = 116, this.child});

  final double height;

  /// The feedback to show, or null to hold the space empty.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: child == null ? null : Center(child: child),
    );
  }
}
