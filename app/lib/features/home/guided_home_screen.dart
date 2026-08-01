import 'dart:async';

import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../lesson/lesson_screen.dart';
import '../profile/avatars.dart';
import '../progress/progress_screen.dart';
import 'journey_ui.dart';
import 'rooms_screen.dart';
import 'world_scenery.dart';

/// The journey's front door: every world as a big **gateway**. Walking
/// through a gate switches to that world's rooms (its own scenery), a room
/// opens onto its lesson path — one screen per tier, so each choice gets the
/// whole stage (see docs/lessons.md). The big Play button skips the walking
/// and jumps straight into the next lesson.
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
  bool _busy = false;
  Timer? _greetTimer;

  @override
  void initState() {
    super.initState();
    // Never strand a non-reader on a silent screen: greet by name and point
    // at the one thing to do.
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
    super.dispose();
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
    setState(() {}); // reflect any level-up
    // Re-orient after the lesson — delayed so a goodbye or level-up line
    // finishes ringing first.
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
          final currentUnit = widget.schedule.unitFor(p.level);
          final units = widget.schedule.units.isEmpty
              ? [currentUnit]
              : widget.schedule.units;
          return Stack(
            fit: StackFit.expand,
            children: [
              // The stage is always the world the child lives in right now.
              WorldScenery(unitId: currentUnit.id),
              SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 18,
                          children: [
                            for (final u in units)
                              _WorldGate(
                                key: Key('world-${u.id}'),
                                unit: u,
                                state: u.levels.every((l) => l < p.level)
                                    ? _GateState.done
                                    : u.id == currentUnit.id
                                        ? _GateState.current
                                        : _GateState.locked,
                                fraction: u.id == currentUnit.id
                                    ? _unitFraction(u, p)
                                    : null,
                                onTap: () {
                                  if (u.levels.first <= p.level) {
                                    _enterWorld(u);
                                  } else {
                                    widget.audioService.speak(
                                        'Locked! Keep playing to get to ${u.title}!');
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    BigPlayButton(onPressed: _openLesson),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _unitFraction(CurriculumUnit u, ProgressService p) {
    final done = u.levels.where((l) => l < p.level).length;
    final inCurrent =
        u.levels.contains(p.level) ? p.levelFraction : 0.0;
    return ((done + inCurrent) / u.levels.length).clamp(0.0, 1.0);
  }
}

enum _GateState { done, current, locked }

/// A world's gateway: a tall arch big enough to feel like a place you enter,
/// wearing the world's landmark and (for the current world) a progress ring.
class _WorldGate extends StatelessWidget {
  const _WorldGate({
    super.key,
    required this.unit,
    required this.state,
    required this.onTap,
    this.fraction,
  });

  final CurriculumUnit unit;
  final _GateState state;
  final double? fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = state == _GateState.current;
    final w = current ? 132.0 : 112.0;
    final h = current ? 158.0 : 136.0;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: w,
                height: h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _GateState.locked
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.9)
                      : scheme.primaryContainer.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(w / 2),
                      bottom: const Radius.circular(16)),
                  border: current
                      ? Border.all(color: scheme.primary, width: 4)
                      : Border.all(color: scheme.outlineVariant, width: 2),
                ),
                child: Opacity(
                  opacity: state == _GateState.locked ? 0.45 : 1,
                  child: Text(unit.emoji,
                      style: TextStyle(fontSize: current ? 56 : 46)),
                ),
              ),
              if (current && fraction != null)
                Positioned(
                  bottom: 8,
                  child: SizedBox(
                    width: w * 0.62,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                          value: fraction, minHeight: 7),
                    ),
                  ),
                ),
              if (state == _GateState.done)
                const Positioned(
                    right: -6,
                    top: -6,
                    child: Icon(Icons.star, color: Colors.amber, size: 30)),
              if (state == _GateState.locked)
                Positioned(
                    right: -4,
                    top: -4,
                    child:
                        Icon(Icons.lock, color: scheme.outline, size: 22)),
            ],
          ),
          const SizedBox(height: 6),
          SceneryChip(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(unit.title,
                style: Theme.of(context).textTheme.labelLarge),
          ),
        ],
      ),
    );
  }
}
