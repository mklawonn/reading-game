import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../learning/lesson_plan.dart';
import '../../models/curriculum.dart';
import '../../progress/progress_service.dart';

/// Shared pieces of the worlds → rooms → lesson-nodes journey UI.

/// The badge a room wears: the level's first pictured new symbol, its first
/// new syllable in print, or a balloon for review rooms.
String levelBadge(CurriculumLevel level) {
  for (final id in level.introduce) {
    final emoji = kPictographEmoji[id];
    if (emoji != null) return emoji;
  }
  if (level.introduce.isNotEmpty) return level.introduce.first;
  return '🎈'; // review room — a party, not new material
}

const Map<LessonTheme, String> kThemeEmoji = {
  LessonTheme.meet: '👋',
  LessonTheme.sounds: '👂',
  LessonTheme.story: '📖',
  LessonTheme.reading: '📚',
};

const Map<LessonTheme, String> kThemeLine = {
  LessonTheme.meet: 'New friends!',
  LessonTheme.sounds: 'Listening games!',
  LessonTheme.story: 'Story time!',
  LessonTheme.reading: 'Reading games!',
};

/// The theme lesson node [i] of [level] will carry (for its icon): the very
/// next node uses live seen-intros; other nodes assume the meet lesson will
/// have happened.
LessonTheme nodeThemeFor(ProgressService p, CurriculumLevel level, int i) {
  if (level.id == p.level && i == p.lessonsIntoLevel) {
    return LessonPlan.themeFor(
        level: level, seenIntros: p.seenIntros, lessonIndex: i);
  }
  if (i == 0 && level.introduce.isNotEmpty) return LessonTheme.meet;
  return LessonPlan.themeFor(
      level: level,
      seenIntros: {...p.seenIntros, ...level.introduce},
      lessonIndex: i);
}

/// Pushes [page] with the "walking through a gate" feel: a gentle
/// fade-and-grow rather than the default slide.
Future<T?> pushImmersive<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 450),
    reverseTransitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 1.08, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  ));
}

/// A translucent chip that keeps text readable over any world scenery.
class SceneryChip extends StatelessWidget {
  const SceneryChip({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// The one big button a child can always find. [keyName] keeps test keys
/// stable per screen.
class BigPlayButton extends StatelessWidget {
  const BigPlayButton({super.key, required this.onPressed, this.keyName = 'home-play'});

  final VoidCallback onPressed;
  final String keyName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 84,
      child: FilledButton(
        key: Key(keyName),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Icon(Icons.play_arrow_rounded, size: 52),
      ),
    );
  }
}

/// Back-arrow + title header used by the rooms and lesson-path screens.
class JourneyHeader extends StatelessWidget {
  const JourneyHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('journey-back'),
            iconSize: 30,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Center(
              child: SceneryChip(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}
