import 'dart:async';

import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/guide_character.dart';
import '../lesson/lesson_screen.dart';
import '../profile/avatars.dart';
import '../progress/progress_screen.dart';
import 'journey_ui.dart';
import 'rooms_screen.dart';
import 'world_scenery.dart';

/// The journey's front door, ABC-style: one continuous **street** of world
/// buildings you page through. The current world stands in color under its
/// own sky (guide hovering beside it); locked worlds wait in greyscale down
/// the road. Tapping a building walks inside (its rooms); the big Play button
/// skips straight to the next lesson.
class GuidedHomeScreen extends StatefulWidget {
  const GuidedHomeScreen({
    super.key,
    required this.progress,
    required this.engine,
    required this.schedule,
    required this.contentService,
    required this.audioService,
    this.profile,
    this.onSwitchProfile,
  });

  final ProgressService progress;
  final CurriculumEngine engine;
  final CurriculumSchedule schedule;
  final ContentService contentService;
  final AudioService audioService;
  final Profile? profile;
  final VoidCallback? onSwitchProfile;

  @override
  State<GuidedHomeScreen> createState() => _GuidedHomeScreenState();
}

class _GuidedHomeScreenState extends State<GuidedHomeScreen> {
  static const double _streetHeight = 92;

  bool _busy = false;
  Timer? _greetTimer;
  late PageController _pages;
  late int _focused; // unit LIST INDEX currently centered
  late List<CurriculumUnit> _units;

  int get _currentIndex {
    final current = widget.schedule.unitFor(widget.progress.level);
    final at = _units.indexWhere((u) => u.id == current.id);
    return at < 0 ? 0 : at;
  }

  @override
  void initState() {
    super.initState();
    _units = widget.schedule.units.isEmpty
        ? [widget.schedule.unitFor(widget.progress.level)]
        : widget.schedule.units;
    _focused = _currentIndex;
    _pages = PageController(viewportFraction: 0.72, initialPage: _focused);
    _pages.addListener(_onPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final name = widget.profile?.name;
      widget.audioService.speak(
        name == null || name.isEmpty
            ? 'Hi! Tap the big button to play!'
            : 'Hi $name! Tap the big button to play!',
      );
    });
  }

  @override
  void dispose() {
    _greetTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Narrate arriving in front of a building as the page settles.
  void _onPage() {
    final page = _pages.hasClients ? _pages.page : null;
    if (page == null) return;
    final settled = page.round();
    if ((page - settled).abs() > 0.02 || settled == _focused) return;
    _focused = settled;
    final unit = _units[settled];
    final locked = unit.levels.first > widget.progress.level;
    widget.audioService
        .speak(locked ? '${unit.title}. Locked!' : '${unit.title}!');
    setState(() {});
  }

  Future<void> _openLesson() async {
    if (_busy) return;
    _busy = true;
    _greetTimer?.cancel();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LessonScreen(
          progress: widget.progress,
          engine: widget.engine,
          schedule: widget.schedule,
          contentService: widget.contentService,
          audioService: widget.audioService,
        ),
      ),
    );
    _busy = false;
    if (!mounted) return;
    setState(() {});
    // A level-up may have moved us down the street — drive there.
    if (_pages.hasClients && _currentIndex != _focused) {
      _pages.animateToPage(_currentIndex,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic);
    }
    _greetTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final p = widget.progress;
      widget.audioService.speak(
        p.pathComplete
            ? 'You did everything! Amazing!'
            : 'Level ${p.level}! Tap the big button to keep going!',
      );
    });
  }

  Future<void> _enterWorld(CurriculumUnit unit) async {
    if (_busy) return;
    _busy = true;
    _greetTimer?.cancel();
    await pushImmersive(
      context,
      RoomsScreen(
        unit: unit,
        progress: widget.progress,
        engine: widget.engine,
        schedule: widget.schedule,
        contentService: widget.contentService,
        audioService: widget.audioService,
      ),
    );
    _busy = false;
    if (mounted) setState(() {});
  }

  double _unitFraction(CurriculumUnit u, ProgressService p) {
    final done = u.levels.where((l) => l < p.level).length;
    final inCurrent = u.levels.contains(p.level) ? p.levelFraction : 0.0;
    return ((done + inCurrent) / u.levels.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.inversePrimary,
        leading: widget.profile == null
            ? null
            : IconButton(
                key: const Key('home-profile'),
                tooltip: 'Switch player',
                onPressed: widget.onSwitchProfile,
                icon: Text(
                  avatarEmoji(widget.profile!.avatar),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
        title: Text(widget.profile?.name ?? 'Reading Game'),
        actions: [
          IconButton(
            key: const Key('home-progress'),
            icon: const Icon(Icons.emoji_events),
            tooltip: 'My progress',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProgressScreen(progress: widget.progress),
              ),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.progress,
        builder: (context, _) {
          final p = widget.progress;
          final focusedUnit = _units[_focused.clamp(0, _units.length - 1)];
          final focusedLocked = focusedUnit.levels.first > p.level;
          final theme = worldThemeFor(focusedUnit.id);
          return Stack(
            fit: StackFit.expand,
            children: [
              // The sky follows whichever building you're in front of —
              // washed grey when it's still locked.
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      for (final c in theme.sky)
                        focusedLocked
                            ? Color.lerp(c, const Color(0xFFB9BEC6), 0.55)!
                            : c,
                    ],
                  ),
                ),
              ),
              // Distant skyline + clouds, sliding slower than the street.
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParallaxBackdropPainter(
                    pages: _pages,
                    fallbackPage: _focused.toDouble(),
                    streetHeight: _streetHeight,
                  ),
                ),
              ),
              // The street itself.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _streetHeight,
                child: const _Street(),
              ),
              // The buildings.
              Positioned.fill(
                bottom: _streetHeight - 10,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _units.length,
                  itemBuilder: (context, i) {
                    final unit = _units[i];
                    final locked = unit.levels.first > p.level;
                    final beaten = unit.levels.every((l) => l < p.level) ||
                        (p.pathComplete && unit.levels.contains(p.level));
                    final isCurrentWorld = i == _currentIndex;
                    return _BuildingPage(
                      key: Key('world-${unit.id}'),
                      unit: unit,
                      locked: locked,
                      beaten: beaten,
                      showGuide: isCurrentWorld,
                      guide: guideForLevel(p.level),
                      fraction: unit.levels.contains(p.level)
                          ? _unitFraction(unit, p)
                          : null,
                      onTap: () {
                        if (locked) {
                          widget.audioService.speak(
                              'Locked! Keep playing to get to ${unit.title}!');
                        } else {
                          _enterWorld(unit);
                        }
                      },
                    );
                  },
                ),
              ),
              if (p.pathComplete)
                const Align(
                  alignment: Alignment(0, -0.85),
                  child: Text('🏆', style: TextStyle(fontSize: 52)),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BigPlayButton(onPressed: _openLesson),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One building on the street: hero art standing on the ground, its name on a
/// chip, greyscale + padlock while locked, the guide hovering beside the
/// current one.
class _BuildingPage extends StatelessWidget {
  const _BuildingPage({
    super.key,
    required this.unit,
    required this.locked,
    required this.beaten,
    required this.showGuide,
    required this.guide,
    required this.onTap,
    this.fraction,
  });

  final CurriculumUnit unit;
  final bool locked;
  final bool beaten;
  final bool showGuide;
  final Guide guide;
  final double? fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  top: 24,
                  child: LockedGrey(
                    locked: locked,
                    child: Image.asset(
                      'assets/images/worlds/building_${unit.id}.png',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomCenter,
                      errorBuilder: (context, error, stack) => Center(
                        child: Text(unit.emoji,
                            style: const TextStyle(fontSize: 90)),
                      ),
                    ),
                  ),
                ),
                if (showGuide)
                  Align(
                    alignment: const Alignment(0.9, -0.72),
                    child: GuideCharacter(guide: guide, size: 44),
                  ),
                if (locked)
                  Align(
                    alignment: const Alignment(0, -0.55),
                    child: Icon(Icons.lock,
                        size: 34,
                        color: Colors.black.withValues(alpha: 0.35)),
                  ),
                if (beaten)
                  const Align(
                    alignment: Alignment(0.85, -0.9),
                    child:
                        Icon(Icons.star, color: Colors.amber, size: 34),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SceneryChip(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${unit.emoji}  ${unit.title}',
                    style: Theme.of(context).textTheme.titleMedium),
                if (fraction != null) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 110,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: fraction, minHeight: 7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Clear the floating Play button so the chip is never hidden.
          const SizedBox(height: 86),
        ],
      ),
    );
  }
}

/// The continuous asphalt + sidewalk strip the whole street stands on.
class _Street extends StatelessWidget {
  const _Street();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 12, color: const Color(0xFFCFCFD8)), // curb
        Expanded(child: Container(color: const Color(0xFF565661))),
      ],
    );
  }
}

/// Soft clouds and a distant skyline that slide at a fraction of the page
/// speed — the parallax that makes the street feel deep.
class _ParallaxBackdropPainter extends CustomPainter {
  _ParallaxBackdropPainter({
    required this.pages,
    required this.fallbackPage,
    required this.streetHeight,
  }) : super(repaint: pages);

  final PageController pages;
  final double fallbackPage;
  final double streetHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final page = pages.hasClients ? (pages.page ?? fallbackPage) : fallbackPage;
    final white = Paint()..color = Colors.white.withValues(alpha: 0.5);
    final far = Paint()..color = Colors.white.withValues(alpha: 0.28);

    // Distant rooftops: one repeating silhouette band, kept behind buildings.
    final skyline = Paint()..color = Colors.white.withValues(alpha: 0.22);
    final baseY = size.height - streetHeight - 8;
    final shift = -page * size.width * 0.18;
    for (var x = -1; x < 5; x++) {
      final ox = shift % (size.width * 0.9) + x * size.width * 0.45;
      canvas.drawRect(
          Rect.fromLTWH(ox, baseY - 130, size.width * 0.16, 130), skyline);
      canvas.drawRect(
          Rect.fromLTWH(ox + size.width * 0.19, baseY - 90,
              size.width * 0.13, 90),
          skyline);
    }
    // Two cloud layers at different parallax rates.
    for (final (rate, y, r, paint) in [
      (0.10, size.height * 0.16, 34.0, far),
      (0.26, size.height * 0.30, 26.0, white),
    ]) {
      final ox = -page * size.width * rate;
      for (var i = 0; i < 4; i++) {
        final cx =
            (ox + i * size.width * 0.55) % (size.width * 1.4) - 60;
        canvas.drawCircle(Offset(cx, y), r, paint);
        canvas.drawCircle(Offset(cx + r * 1.1, y + 6), r * 0.75, paint);
        canvas.drawCircle(Offset(cx - r * 1.0, y + 8), r * 0.7, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ParallaxBackdropPainter old) =>
      old.pages != pages || old.streetHeight != streetHeight;
}
