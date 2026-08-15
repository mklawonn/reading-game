import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../learning/lesson_plan.dart';
import '../../models/curriculum.dart';
import '../../progress/progress_service.dart';

/// Shared pieces of the worlds → rooms → lesson-nodes journey UI.

/// Desaturates + lifts a locked thing, ABC-style: the world is visible (a
/// promise) but clearly not-yet (greyscale). No padlock badge needed on big
/// art, though callers may add one.
class LockedGrey extends StatelessWidget {
  const LockedGrey({super.key, required this.locked, required this.child});

  final bool locked;
  final Widget child;

  static const ColorFilter _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 30,
    0.2126, 0.7152, 0.0722, 0, 30,
    0.2126, 0.7152, 0.0722, 0, 30,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return ColorFiltered(colorFilter: _grey, child: child);
  }
}

/// A chunky pseudo-3D button node (the ABC coin look): a face circle sitting
/// on a darker bottom rim, pressing down on touch. The whole journey's
/// tappable circles share this so everything feels physically pushable.
class RaisedNode extends StatefulWidget {
  const RaisedNode({
    super.key,
    required this.size,
    required this.color,
    required this.child,
    this.onTap,
    this.ring = false,
  });

  final double size;
  final Color color;
  final Widget child;
  final VoidCallback? onTap;

  /// Highlight ring for "you are here".
  final bool ring;

  @override
  State<RaisedNode> createState() => _RaisedNodeState();
}

class _RaisedNodeState extends State<RaisedNode> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rim = HSLColor.fromColor(widget.color)
        .withLightness(max(
            0, HSLColor.fromColor(widget.color).lightness - 0.22))
        .toColor();
    final drop = widget.size * 0.10;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size + 8,
        height: widget.size + drop + 8,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // The rim: the button's thickness.
            Positioned(
              top: drop + 4,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rim,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
            // The face, dropping onto the rim while pressed.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              top: _pressed ? drop + 1 : 4,
              child: Container(
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HSLColor.fromColor(widget.color)
                          .withLightness(min(
                              1.0,
                              HSLColor.fromColor(widget.color).lightness +
                                  0.08))
                          .toColor(),
                      widget.color,
                    ],
                  ),
                  border: widget.ring
                      ? Border.all(color: scheme.primary, width: 4)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The inside of a building: warm wood paneling (deterministic plank tones),
/// shared by the rooms and lesson-path screens so "entering" reads as walking
/// indoors, straight out of the ABC interior.
class InteriorBackground extends StatelessWidget {
  const InteriorBackground({super.key, this.tint});

  /// Optional world accent blended faintly into the wood.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _PlankPainter(tint), size: Size.infinite);
  }
}

class _PlankPainter extends CustomPainter {
  _PlankPainter(this.tint);

  final Color? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final base = tint == null
        ? const Color(0xFF5D4B3F)
        : Color.lerp(const Color(0xFF5D4B3F), tint, 0.12)!;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final rand = Random(7);
    const plankW = 46.0;
    final cols = (size.width / plankW).ceil();
    for (var c = 0; c < cols; c++) {
      final tone = (rand.nextDouble() - 0.5) * 0.08;
      final col = HSLColor.fromColor(base);
      canvas.drawRect(
        Rect.fromLTWH(c * plankW, 0, plankW, size.height),
        Paint()
          ..color = col
              .withLightness((col.lightness + tone).clamp(0.0, 1.0))
              .toColor(),
      );
      // plank gap
      canvas.drawRect(
        Rect.fromLTWH(c * plankW - 1.5, 0, 3, size.height),
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      // a horizontal seam per plank at a stable pseudo-random height
      final seamY = ((c * 7919) % 11) / 11 * size.height;
      canvas.drawRect(
        Rect.fromLTWH(c * plankW, seamY, plankW, 3),
        Paint()..color = Colors.black.withValues(alpha: 0.14),
      );
    }
  }

  @override
  bool shouldRepaint(_PlankPainter old) => old.tint != tint;
}

/// A bottom-up winding trail of nodes (the ABC climb): node 0 starts at the
/// bottom, the path snakes upward, dotted breadcrumbs connect the stops.
class WindingPath extends StatelessWidget {
  const WindingPath({
    super.key,
    required this.count,
    required this.doneUntil,
    required this.nodeSize,
    required this.nodeBuilder,
    this.marker,
    this.markerIndex,
  });

  final int count;

  /// Trail segments below this node index render as "walked".
  final int doneUntil;
  final double nodeSize;
  final Widget Function(int index) nodeBuilder;

  /// An optional "you are here" figure standing on the trail (the guide).
  /// [markerIndex] may be fractional — the marker walks between nodes when
  /// it animates (Duolingo's post-lesson hop).
  final Widget? marker;
  final double? markerIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final topPad = nodeSize * 0.7 + 10;
      final bottomPad = nodeSize * 0.7 + 14;
      final step =
          count <= 1 ? 0.0 : (h - topPad - bottomPad) / (count - 1);
      final points = [
        for (var i = 0; i < count; i++)
          Offset(
            w * (0.5 + (count <= 1 ? 0 : 0.24 * (i.isEven ? -1 : 1))),
            h - bottomPad - i * step,
          ),
      ];
      final box = nodeSize + 8;
      return Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DottedTrailPainter(
                points: points,
                doneUntil: doneUntil,
                doneColor: Colors.amber,
                todoColor: scheme.surface.withValues(alpha: 0.5),
              ),
            ),
          ),
          for (var i = 0; i < count; i++)
            Positioned(
              left: points[i].dx - box / 2,
              top: points[i].dy - box / 2,
              child: nodeBuilder(i),
            ),
          if (marker != null && markerIndex != null && count > 0)
            () {
              final t = markerIndex!.clamp(0.0, (count - 1).toDouble());
              final lo = points[t.floor()];
              final hi = points[t.ceil()];
              final pos = Offset.lerp(lo, hi, t - t.floor())!;
              // Hop: rise mid-stride between two nodes.
              final hop = sin((t - t.floor()) * pi) * 26;
              return Positioned(
                left: pos.dx - 22,
                top: pos.dy - nodeSize / 2 - 46 - hop,
                child: IgnorePointer(child: marker!),
              );
            }(),
        ],
      );
    });
  }
}

/// The dotted trail between journey nodes (the ABC breadcrumb walk).
class DottedTrailPainter extends CustomPainter {
  DottedTrailPainter({required this.points, required this.doneUntil,
      required this.doneColor, required this.todoColor});

  final List<Offset> points;
  final int doneUntil; // trail segments before this index are "walked"
  final Color doneColor;
  final Color todoColor;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final seg = (b - a);
      final len = seg.distance;
      final n = max(3, (len / 26).floor());
      for (var k = 1; k < n; k++) {
        final p = a + seg * (k / n);
        canvas.drawCircle(
            p,
            5,
            Paint()
              ..color = (i < doneUntil ? doneColor : todoColor)
                  .withValues(alpha: 0.85));
      }
    }
  }

  @override
  bool shouldRepaint(DottedTrailPainter old) =>
      old.points != points || old.doneUntil != doneUntil;
}

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
