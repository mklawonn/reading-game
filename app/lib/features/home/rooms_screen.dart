import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../lesson/lesson_screen.dart';
import 'journey_ui.dart';
import 'lesson_path_screen.dart';
import 'world_scenery.dart';

/// Tier 2 of the journey: inside one world, its rooms as doorways. Beaten and
/// current rooms open onto their lesson paths; future rooms wait behind a
/// lock. This screen wears its world's scenery — stepping through a gate
/// should feel like arriving somewhere.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    required this.unit,
    required this.progress,
    required this.engine,
    required this.schedule,
    required this.contentService,
    required this.audioService,
  });

  final CurriculumUnit unit;
  final ProgressService progress;
  final CurriculumEngine engine;
  final CurriculumSchedule schedule;
  final ContentService contentService;
  final AudioService audioService;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.audioService
        .speak('${widget.unit.title}! Tap a door to go in!'));
  }

  Future<void> _openRoom(int levelId) async {
    if (_busy) return;
    _busy = true;
    await pushImmersive(
      context,
      LessonPathScreen(
        levelId: levelId,
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

  Future<void> _playNext() async {
    if (_busy) return;
    _busy = true;
    await pushImmersive(
      context,
      LessonScreen(
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          WorldScenery(unitId: widget.unit.id),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.progress,
              builder: (context, _) {
                final p = widget.progress;
                final currentHere = widget.unit.levels.contains(p.level);
                return Column(
                  children: [
                    JourneyHeader(
                        title:
                            '${widget.unit.emoji}  ${widget.unit.title}'),
                    const Spacer(),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        for (final id in widget.unit.levels)
                          _RoomDoor(
                            key: Key('room-$id'),
                            badge: levelBadge(widget.schedule.levelAt(id)),
                            title: widget.schedule.levelAt(id).title,
                            state: id < p.level
                                ? _DoorState.done
                                : id == p.level
                                    ? _DoorState.current
                                    : _DoorState.locked,
                            onTap: () {
                              if (id <= p.level) {
                                _openRoom(id);
                              } else {
                                widget.audioService.speak(
                                    'Locked! Keep playing to get there!');
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    if (currentHere)
                      BigPlayButton(keyName: 'rooms-play', onPressed: _playNext),
                    const Spacer(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

enum _DoorState { done, current, locked }

/// A doorway into a room: arch-topped, wearing the room's symbol badge.
class _RoomDoor extends StatelessWidget {
  const _RoomDoor({
    super.key,
    required this.badge,
    required this.title,
    required this.state,
    required this.onTap,
  });

  final String badge;
  final String title;
  final _DoorState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = state == _DoorState.current;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: current ? 104 : 92,
                height: current ? 128 : 112,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: state == _DoorState.done
                      ? scheme.primaryContainer
                      : current
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.92),
                  // The arch: a doorway, not a chip.
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(60), bottom: Radius.circular(14)),
                  border: current
                      ? Border.all(color: scheme.primary, width: 4)
                      : Border.all(
                          color: scheme.outlineVariant, width: 2),
                ),
                child: Opacity(
                  opacity: state == _DoorState.locked ? 0.45 : 1,
                  child: Text(badge,
                      style: TextStyle(fontSize: current ? 44 : 38)),
                ),
              ),
              if (state == _DoorState.done)
                const Positioned(
                    right: -4,
                    top: -4,
                    child:
                        Icon(Icons.star, color: Colors.amber, size: 26)),
              if (state == _DoorState.locked)
                Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(Icons.lock,
                        color: scheme.outline, size: 20)),
            ],
          ),
          const SizedBox(height: 6),
          SceneryChip(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(title,
                style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}
