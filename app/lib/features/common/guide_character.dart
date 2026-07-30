import 'dart:math';

import 'package:flutter/material.dart';

/// How the guide is feeling — set by the lesson as the child plays.
enum GuideMood { idle, happy, sad, cheer }

/// The small cast of guide characters. One guide fronts each level
/// (deterministic by level id) so faces rotate but stay stable within a level.
class Guide {
  const Guide(this.emoji, this.name);
  final String emoji;
  final String name;
}

const List<Guide> kGuides = [
  Guide('🦊', 'Fern'),
  Guide('🐻', 'Bo'),
  Guide('🐸', 'Pip'),
  Guide('🦉', 'Olive'),
  Guide('🐼', 'Momo'),
  Guide('🐯', 'Taz'),
];

Guide guideForLevel(int level) => kGuides[(level - 1) % kGuides.length];

/// An animated emoji mascot — the app's face until real art lands. It breathes
/// while idle, jumps when [GuideMood.happy], wobbles sympathetically when
/// [GuideMood.sad], and bounces repeatedly for [GuideMood.cheer]. Reacting to
/// every answer is the Duolingo-ABC-style "someone is playing with me" signal,
/// delivered without any text.
class GuideCharacter extends StatefulWidget {
  const GuideCharacter({
    super.key,
    required this.guide,
    this.mood = GuideMood.idle,
    this.size = 44,
  });

  final Guide guide;
  final GuideMood mood;
  final double size;

  @override
  State<GuideCharacter> createState() => _GuideCharacterState();
}

class _GuideCharacterState extends State<GuideCharacter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _applyMood();
  }

  @override
  void didUpdateWidget(GuideCharacter old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) _applyMood();
  }

  // Every mood runs a *finite* animation (so screens can still settle —
  // pumpAndSettle in tests, battery in production); liveliness comes from
  // multi-bounce curves rather than endless repeats.
  void _applyMood() {
    _controller.stop();
    _controller.value = 0;
    switch (widget.mood) {
      case GuideMood.idle:
        break; // at rest
      case GuideMood.happy:
        _controller.duration = const Duration(milliseconds: 550);
        _controller.forward();
      case GuideMood.sad:
        _controller.duration = const Duration(milliseconds: 600);
        _controller.forward();
      case GuideMood.cheer:
        _controller.duration = const Duration(milliseconds: 1600);
        _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        double dy = 0, angle = 0, scale = 1;
        switch (widget.mood) {
          case GuideMood.idle:
            break; // at rest
          case GuideMood.happy:
            dy = -widget.size * 0.35 * sin(t * pi); // one clean jump
            scale = 1 + 0.15 * sin(t * pi);
          case GuideMood.sad:
            angle = 0.16 * sin(t * pi * 3) * (1 - t); // damped head-shake
          case GuideMood.cheer:
            // Three party bounces with a little sway, then rest.
            dy = -widget.size * 0.3 * sin(t * pi * 3).abs() * (1 - t * 0.3);
            angle = 0.1 * sin(t * pi * 6);
            scale = 1 + 0.08 * sin(t * pi * 3).abs();
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Text(
        widget.guide.emoji,
        style: TextStyle(fontSize: widget.size),
      ),
    );
  }
}
