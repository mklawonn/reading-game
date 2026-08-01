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

/// Tier 3 of the journey: one room's lesson nodes on their own focused
/// screen. The next node glows and plays; completed nodes (and every node of
/// an already-beaten room) replay freely — replays practice and celebrate but
/// never move the level ladder.
class LessonPathScreen extends StatefulWidget {
  const LessonPathScreen({
    super.key,
    required this.levelId,
    required this.progress,
    required this.engine,
    required this.schedule,
    required this.contentService,
    required this.audioService,
  });

  final int levelId;
  final ProgressService progress;
  final CurriculumEngine engine;
  final CurriculumSchedule schedule;
  final ContentService contentService;
  final AudioService audioService;

  @override
  State<LessonPathScreen> createState() => _LessonPathScreenState();
}

class _LessonPathScreenState extends State<LessonPathScreen> {
  bool _busy = false;

  CurriculumLevel get _level => widget.schedule.levelAt(widget.levelId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        widget.audioService.speak('${_level.title}! Tap a circle to play!'));
  }

  Future<void> _play({int? nodeIndex}) async {
    if (_busy) return;
    _busy = true;
    final p = widget.progress;
    final isCurrentNext = widget.levelId == p.level &&
        (nodeIndex == null || nodeIndex == p.lessonsIntoLevel);
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
    if (mounted) setState(() {});
  }

  void _onTapNode(int i) {
    final p = widget.progress;
    if (widget.levelId > p.level) return; // unreachable via UI, but safe
    final isCurrent = widget.levelId == p.level;
    if (!isCurrent || i <= p.lessonsIntoLevel) {
      _play(nodeIndex: i);
    } else {
      widget.audioService
          .speak(kThemeLine[nodeThemeFor(p, _level, i)] ?? 'Soon!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unit = widget.schedule.unitFor(widget.levelId);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          WorldScenery(unitId: unit.id),
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
                          guide: guideForLevel(widget.levelId), size: 40),
                    ),
                    const Spacer(),
                    // The nodes, big and focused — this screen is about
                    // exactly one room.
                    Wrap(
                      key: const Key('path-nodes'),
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 14,
                      children: [
                        for (var i = 0; i < level.lessons; i++) ...[
                          _PathNode(
                            key: Key('path-node-$i'),
                            emoji:
                                kThemeEmoji[nodeThemeFor(p, level, i)] ?? '⭐',
                            state: i < done
                                ? _NodeState.done
                                : (widget.levelId == p.level &&
                                        i == p.lessonsIntoLevel)
                                    ? _NodeState.current
                                    : _NodeState.locked,
                            onTap: () => _onTapNode(i),
                          ),
                          if (i != level.lessons - 1)
                            Container(
                              width: 26,
                              height: 6,
                              decoration: BoxDecoration(
                                color: i < done
                                    ? scheme.primary
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 30),
                    BigPlayButton(
                      keyName: 'path-play',
                      onPressed: () => _play(
                          nodeIndex:
                              widget.levelId == p.level ? null : 0),
                    ),
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

enum _NodeState { done, current, locked }

class _PathNode extends StatelessWidget {
  const _PathNode(
      {super.key, required this.emoji, required this.state, required this.onTap});

  final String emoji;
  final _NodeState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = state == _NodeState.current;
    final size = current ? 78.0 : 64.0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: state == _NodeState.done
                  ? scheme.primary
                  : current
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.9),
              border:
                  current ? Border.all(color: scheme.primary, width: 4) : null,
            ),
            child: Opacity(
              opacity: state == _NodeState.locked ? 0.45 : 1,
              child:
                  Text(emoji, style: TextStyle(fontSize: current ? 34 : 28)),
            ),
          ),
          if (state == _NodeState.done)
            Positioned(
              right: -2,
              bottom: -2,
              child: Icon(Icons.replay_circle_filled_rounded,
                  color: Colors.green.shade600, size: 24),
            ),
        ],
      ),
    );
  }
}
