import 'dart:async';

import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/guide_character.dart';
import '../lesson/lesson_screen.dart';
import 'journey_ui.dart';
import 'world_scenery.dart';

/// Tier 3 of the journey: one room's lesson nodes climbing the interior wall
/// bottom-up on a dotted trail — completed nodes turn to gold coins
/// (replayable), the next one glows with its theme, later ones wait dark.
/// Replays practice and celebrate but never move the level ladder.
class LessonPathScreen extends StatefulWidget {
  const LessonPathScreen({
    super.key,
    required this.levelId,
    required this.progress,
    required this.engine,
    required this.schedule,
    required this.contentService,
    required this.audioService,
    this.autoPlay = false,
  });

  final int levelId;
  final ProgressService progress;
  final CurriculumEngine engine;
  final CurriculumSchedule schedule;
  final ContentService contentService;
  final AudioService audioService;

  /// Launch the next lesson immediately (the Play-button route): the child
  /// still lands back HERE afterwards, so the marker's forward hop is always
  /// seen. Leaving that lesson without progress pops straight back through.
  final bool autoPlay;

  @override
  State<LessonPathScreen> createState() => _LessonPathScreenState();
}

class _LessonPathScreenState extends State<LessonPathScreen> {
  bool _busy = false;
  double _markerFrom = 0;
  double _markerTo = 0;
  Timer? _closeTimer;
  bool _roomJustFinished = false;

  CurriculumLevel get _level => widget.schedule.levelAt(widget.levelId);

  int _doneCount() {
    final p = widget.progress;
    return widget.levelId < p.level
        ? _level.lessons
        : (widget.levelId == p.level ? p.lessonsIntoLevel : 0);
  }

  @override
  void initState() {
    super.initState();
    _markerFrom = _markerTo = _doneCount().toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoPlay) {
        _play();
      } else {
        widget.audioService.speak('${_level.title}! Tap a circle to play!');
      }
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _play({int? nodeIndex}) async {
    if (_busy) return;
    _busy = true;
    final p = widget.progress;
    final isCurrentNext =
        widget.levelId == p.level &&
        (nodeIndex == null || nodeIndex == p.lessonsIntoLevel);
    final wasCurrent = widget.levelId == p.level;
    final before = _doneCount();
    await pushImmersive(
      context,
      LessonScreen(
        progress: p,
        engine: widget.engine,
        schedule: widget.schedule,
        contentService: widget.contentService,
        audioService: widget.audioService,
        levelOverride: isCurrentNext ? null : widget.levelId,
        lessonIndexOverride: isCurrentNext ? null : nodeIndex,
      ),
    );
    _busy = false;
    if (!mounted) return;
    final after = _doneCount();
    final roomFinished = wasCurrent && p.level > widget.levelId;
    if (after > before || roomFinished) {
      _roomJustFinished = roomFinished;
      if (roomFinished) {
        widget.audioService.speak(
          '${_level.title} — all done! On to the next one!',
        );
        _closeTimer = Timer(const Duration(milliseconds: 2700), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      // Let the pop transition finish first, THEN hop in full view. A
      // finished room hops past the last node and off the top ("on we go");
      // a finished lesson hops to the next glowing node.
      Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() {
          _markerFrom = before.toDouble();
          _markerTo = roomFinished
              ? _level.lessons.toDouble()
              : after.toDouble();
        });
      });
      setState(() {});
    } else if (widget.autoPlay) {
      // Play-button route with nothing gained (left early): step back out.
      Navigator.of(context).maybePop();
      return;
    } else {
      setState(() {});
    }
  }

  void _onTapNode(int i) {
    final p = widget.progress;
    if (widget.levelId > p.level) return; // unreachable via UI, but safe
    final isCurrent = widget.levelId == p.level;
    if (!isCurrent || i <= p.lessonsIntoLevel) {
      _play(nodeIndex: i);
    } else {
      widget.audioService.speak(
        kThemeLine[nodeThemeFor(p, _level, i)] ?? 'Soon!',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.schedule.unitFor(widget.levelId);
    final accent = worldThemeFor(unit.id).sky.first;
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
                final level = _level;
                final done = widget.levelId < p.level
                    ? level.lessons
                    : (widget.levelId == p.level ? p.lessonsIntoLevel : 0);
                return Column(
                  children: [
                    JourneyHeader(
                      title: '${levelBadge(level)}  ${level.title}',
                      trailing: GuideCharacter(
                        guide: guideForLevel(widget.levelId),
                        size: 40,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey('marker-$_markerFrom-$_markerTo'),
                          tween: Tween(begin: _markerFrom, end: _markerTo),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeInOutCubic,
                          builder: (context, markerAt, _) => WindingPath(
                            count: level.lessons,
                            doneUntil: done,
                            nodeSize: 88,
                            marker:
                                (widget.levelId == p.level || _roomJustFinished)
                                ? GuideCharacter(
                                    guide: guideForLevel(widget.levelId),
                                    mood:
                                        markerAt != _markerTo ||
                                            _roomJustFinished
                                        ? GuideMood.happy
                                        : GuideMood.idle,
                                    size: 40,
                                  )
                                : null,
                            markerIndex: markerAt,
                            nodeBuilder: (i) {
                              final isDone = i < done;
                              final isCurrent =
                                  widget.levelId == p.level &&
                                  i == p.lessonsIntoLevel;
                              return RaisedNode(
                                key: Key('path-node-$i'),
                                size: 88,
                                ring: isCurrent,
                                color: isDone
                                    ? Colors.amber
                                    : isCurrent
                                    ? Color.lerp(accent, Colors.white, 0.25)!
                                    : const Color(0xFF473A31),
                                onTap: () => _onTapNode(i),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      opacity: isDone || isCurrent ? 1 : 0.5,
                                      child: Text(
                                        kThemeEmoji[nodeThemeFor(
                                              p,
                                              level,
                                              i,
                                            )] ??
                                            '⭐',
                                        style: TextStyle(
                                          fontSize: isCurrent ? 38 : 32,
                                        ),
                                      ),
                                    ),
                                    if (isDone)
                                      const Align(
                                        alignment: Alignment(0.9, 0.9),
                                        child: Icon(
                                          Icons.replay_circle_filled_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: BigPlayButton(
                        keyName: 'path-play',
                        onPressed: () => _play(
                          nodeIndex: widget.levelId == p.level ? null : 0,
                        ),
                      ),
                    ),
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
