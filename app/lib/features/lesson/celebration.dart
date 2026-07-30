import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../common/guide_character.dart';

/// End-of-lesson celebration: confetti, a cheering guide, 1–3 stars popping in
/// one by one, and a spoken "You did it!" — the finish line every lesson runs
/// toward. Purely visual+audio (no reading required); the single big button
/// continues home.
class CelebrationView extends StatefulWidget {
  const CelebrationView({
    super.key,
    required this.stars,
    required this.guide,
    required this.audioService,
    required this.onContinue,
  });

  /// 1–3, from lesson accuracy.
  final int stars;
  final Guide guide;
  final AudioService audioService;
  final VoidCallback onContinue;

  @override
  State<CelebrationView> createState() => _CelebrationViewState();
}

class _CelebrationViewState extends State<CelebrationView>
    with SingleTickerProviderStateMixin {
  /// The whole show: confetti rains for the full duration (finite, so tests
  /// and batteries can settle — long enough that the child, not the clock,
  /// ends the moment). Stars pop within the first [_starPhase].
  static const Duration _show = Duration(seconds: 15);
  static const Duration _starPhase = Duration(milliseconds: 2400);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _show,
  )..forward();

  /// 0..1 over the star phase (the first 2.4s), then holds at 1.
  double get _starT => (_controller.value *
          _show.inMilliseconds /
          _starPhase.inMilliseconds)
      .clamp(0.0, 1.0);

  /// Monotonic confetti clock — the painter wraps particles itself, so this
  /// just keeps rising for the whole show.
  double get _confettiT =>
      _controller.value * _show.inMilliseconds / _starPhase.inMilliseconds;

  static const _praise = ['You did it!', 'Hooray!', 'Great reading!'];

  @override
  void initState() {
    super.initState();
    final line = _praise[Random().nextInt(_praise.length)];
    final stars = switch (widget.stars) {
      3 => 'Three stars!',
      2 => 'Two stars!',
      _ => 'One star!',
    };
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.audioService.speak('$line $stars'));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Pop-in scale for star [i]: staggered, springy.
  double _starScale(int i, double t) {
    final start = 0.15 + i * 0.22;
    final local = ((t - start) / 0.3).clamp(0.0, 1.0);
    return Curves.elasticOut.transform(local);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _ConfettiPainter(
                progress: _confettiT,
                colors: [
                  scheme.primary,
                  scheme.tertiary,
                  scheme.secondary,
                  Colors.amber,
                  Colors.pinkAccent,
                ],
              ),
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GuideCharacter(
                  guide: widget.guide, mood: GuideMood.cheer, size: 96),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // All three slots are always drawn (outline underlay), so
                    // mid-animation the child never sees fewer slots than
                    // stars being announced — earned stars pop in on top.
                    for (var i = 0; i < 3; i++)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.star_outline_rounded,
                              size: 72, color: scheme.outlineVariant),
                          if (i < widget.stars)
                            Transform.scale(
                              scale: _starScale(i, _starT),
                              child: Icon(
                                Icons.star_rounded,
                                key: Key('celebrate-star-$i'),
                                size: 72,
                                color: Colors.amber,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 72,
                child: FilledButton(
                  key: const Key('celebrate-continue'),
                  onPressed: widget.onContinue,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 40),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  // Deterministic particle field (stable across repaints).
  static final List<_Particle> _particles = () {
    final r = Random(7);
    return [
      for (var i = 0; i < 60; i++)
        _Particle(
          x: r.nextDouble(),
          speed: 0.6 + r.nextDouble() * 0.8,
          size: 5 + r.nextDouble() * 7,
          spin: (r.nextDouble() - 0.5) * 10,
          colorIndex: i,
          phase: r.nextDouble(),
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _particles) {
      final fall = (progress * p.speed + p.phase) % 1.0;
      final dx = p.x * size.width + sin((progress * 4 + p.phase) * pi * 2) * 12;
      final dy = fall * (size.height + 40) - 20;
      paint.color =
          colors[p.colorIndex % colors.length].withValues(alpha: 0.85);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(progress * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset.zero, width: p.size, height: p.size * 0.6),
            const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  const _Particle({
    required this.x,
    required this.speed,
    required this.size,
    required this.spin,
    required this.colorIndex,
    required this.phase,
  });

  final double x;
  final double speed;
  final double size;
  final double spin;
  final int colorIndex;
  final double phase;
}
