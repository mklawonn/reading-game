import 'dart:math';

import 'package:flutter/material.dart';

import '../../progress/progress_service.dart';

/// A Candy-Crush-style winding **level ladder**, driven purely by the XP curve
/// (`ProgressService.level` / `xpIntoLevel` / `xpForThisLevel`). It is a
/// decoupled *reward* path — it deliberately knows nothing about specific
/// content or stages, just points earned. Completed levels are filled, the
/// current level shows an XP ring, future levels are locked. Scrolls
/// horizontally and auto-centers the current level.
class LevelMap extends StatefulWidget {
  const LevelMap({super.key, required this.progress, this.lookahead = 4});

  final ProgressService progress;

  /// How many locked levels to show beyond the current one.
  final int lookahead;

  @override
  State<LevelMap> createState() => _LevelMapState();
}

class _LevelMapState extends State<LevelMap> {
  static const double _nodeR = 26;
  static const double _hGap = 92;
  static const double _amp = 44;
  static const double _pad = 24;

  final ScrollController _controller = ScrollController();
  int _centeredLevel = -1;

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_onProgressChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());
  }

  @override
  void didUpdateWidget(LevelMap old) {
    super.didUpdateWidget(old);
    if (!identical(old.progress, widget.progress)) {
      old.progress.removeListener(_onProgressChanged);
      widget.progress.addListener(_onProgressChanged);
      _centeredLevel = -1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent());
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgressChanged);
    _controller.dispose();
    super.dispose();
  }

  // Keep the current node centered as levels are gained (e.g. returning home
  // after beating a level) — initState's one-shot centering goes stale.
  void _onProgressChanged() {
    if (widget.progress.level == _centeredLevel) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerCurrent(animated: true));
  }

  double _x(int i) => _pad + _nodeR + i * _hGap;
  double _y(int i, double midY) => midY + _amp * sin(i * pi / 2);

  void _centerCurrent({bool animated = false}) {
    if (!mounted || !_controller.hasClients) return;
    final current = widget.progress.level;
    _centeredLevel = current;
    final target = (_x(current - 1) -
            _controller.position.viewportDimension / 2 +
            _nodeR)
        .clamp(0.0, _controller.position.maxScrollExtent);
    if (animated) {
      _controller.animateTo(target,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      _controller.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    // With a curriculum schedule, the path is exactly its levels — don't draw
    // phantom locked nodes past the end. Without one, fall back to a window.
    final levels = p.totalLevels > 0
        ? p.totalLevels
        : max(p.level + widget.lookahead, 8);
    final height = 2 * _amp + 2 * _nodeR + 2 * _pad;
    final midY = height / 2;
    final width = _x(levels - 1) + _nodeR + _pad;
    final points = [for (var i = 0; i < levels; i++) Offset(_x(i), _y(i, midY))];

    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              // Connecting trail behind the nodes.
              Positioned.fill(
                child: CustomPaint(
                  painter: _TrailPainter(
                    points: points,
                    currentLevel: p.level,
                    reached: Theme.of(context).colorScheme.primary,
                    locked: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              for (var i = 0; i < levels; i++)
                Positioned(
                  left: points[i].dx - _nodeR - (i + 1 == p.level ? 4 : 0),
                  top: points[i].dy - _nodeR - (i + 1 == p.level ? 4 : 0),
                  child: _LevelNode(
                    level: i + 1,
                    current: p.level,
                    radius: _nodeR,
                    xpFraction: p.xpForThisLevel == 0
                        ? 0
                        : p.xpIntoLevel / p.xpForThisLevel,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter({
    required this.points,
    required this.currentLevel,
    required this.reached,
    required this.locked,
  });

  final List<Offset> points;
  final int currentLevel;
  final Color reached;
  final Color locked;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      // A segment is "earned" once its right-hand node has been reached.
      stroke.color = (i + 2 <= currentLevel) ? reached : locked;
      canvas.drawLine(points[i], points[i + 1], stroke);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.currentLevel != currentLevel || old.points != points;
}

class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.level,
    required this.current,
    required this.radius,
    required this.xpFraction,
  });

  final int level;
  final int current;
  final double radius;
  final double xpFraction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = level < current;
    final isCurrent = level == current;
    final r = isCurrent ? radius + 4 : radius;

    final Color bg;
    final Color fg;
    if (done) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (isCurrent) {
      bg = scheme.primaryContainer;
      fg = scheme.onPrimaryContainer;
    } else {
      bg = scheme.surfaceContainerHighest;
      fg = scheme.outline;
    }

    final Widget face = Container(
      width: r * 2,
      height: r * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: isCurrent ? Border.all(color: scheme.primary, width: 2) : null,
      ),
      child: done
          ? Icon(Icons.star, color: fg, size: r)
          : isCurrent
              ? Text('$level',
                  style: TextStyle(
                      color: fg, fontWeight: FontWeight.bold, fontSize: r * 0.8))
              : Icon(Icons.lock, color: fg, size: r * 0.8),
    );

    if (!isCurrent) return face;
    // Current level: wrap the node in an XP-fill ring.
    return SizedBox(
      width: r * 2 + 10,
      height: r * 2 + 10,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: r * 2 + 10,
            height: r * 2 + 10,
            child: CircularProgressIndicator(
              value: xpFraction.clamp(0.0, 1.0),
              strokeWidth: 5,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          face,
        ],
      ),
    );
  }
}
