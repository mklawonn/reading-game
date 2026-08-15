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

/// Tier 2 of the journey: **inside** the world's building — warm wood
/// paneling, and the rooms as big pressable coins climbing a winding dotted
/// trail (bottom-up, the ABC interior). Beaten rooms are gold and replayable;
/// the current room glows; locked rooms wait dark above.
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
        .speak('${widget.unit.title}! Tap a gold coin to play again, '
            'or the glowing one to keep going!'));
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
    final scheme = Theme.of(context).colorScheme;
    final accent = worldThemeFor(widget.unit.id).sky.first;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteriorBackground(tint: accent),
          SafeArea(
            child: ListenableBuilder(
              listenable: widget.progress,
              builder: (context, _) {
                final p = widget.progress;
                final levels = widget.unit.levels;
                final doneCount =
                    levels.where((l) => l < p.level).length;
                final currentHere = levels.contains(p.level);
                return Column(
                  children: [
                    JourneyHeader(
                        title: '${widget.unit.emoji}  ${widget.unit.title}'),
                    Expanded(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: WindingPath(
                          count: levels.length,
                          doneUntil: doneCount,
                          nodeSize: 96,
                          nodeBuilder: (i) {
                            final id = levels[i];
                            final level = widget.schedule.levelAt(id);
                            final done = id < p.level;
                            final current = id == p.level;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                RaisedNode(
                                  key: Key('room-$id'),
                                  size: 96,
                                  ring: current,
                                  color: done
                                      ? Colors.amber
                                      : current
                                          ? Color.lerp(accent,
                                              Colors.white, 0.25)!
                                          : const Color(0xFF473A31),
                                  onTap: () {
                                    if (id <= p.level) {
                                      _openRoom(id);
                                    } else {
                                      widget.audioService.speak(
                                          'Locked! Keep playing to get there!');
                                    }
                                  },
                                  child: done || current
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Text(levelBadge(level),
                                                style: const TextStyle(
                                                    fontSize: 42)),
                                            if (done)
                                              const Align(
                                                alignment:
                                                    Alignment(0.9, 0.9),
                                                child: Icon(
                                                    Icons
                                                        .replay_circle_filled_rounded,
                                                    color: Colors.white,
                                                    size: 26),
                                              ),
                                          ],
                                        )
                                      : Icon(Icons.lock,
                                          color: Colors.white
                                              .withValues(alpha: 0.55),
                                          size: 34),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    if (currentHere)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BigPlayButton(
                            keyName: 'rooms-play', onPressed: _playNext),
                      )
                    else
                      const SizedBox(height: 14),
                  ],
                );
              },
            ),
          ),
          // A floor line grounding the lowest node, like the ABC shelf.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: 10,
                color: scheme.shadow.withValues(alpha: 0.25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
