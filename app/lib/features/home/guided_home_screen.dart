import 'dart:async';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../learning/curriculum_engine.dart';
import '../../learning/lesson_plan.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../lesson/lesson_screen.dart';
import '../profile/avatars.dart';
import '../progress/progress_screen.dart';

/// The guided home, organized in three tiers (docs/lessons.md):
///
///   worlds (emoji landmarks) → rooms (this world's sub-levels, each wearing
///   the symbols it teaches) → lesson nodes (the bite-sized path, each node
///   showing its theme: meet 👋 / sounds 👂 / story 📖 / reading 📚)
///
/// One big **Play** button always launches the next node. Everything answers
/// aloud when tapped — nothing on this screen requires reading.
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
      widget.audioService.speak(name == null || name.isEmpty
          ? 'Hi! Tap the big button to play!'
          : 'Hi $name! Tap the big button to play!');
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
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LessonScreen(
        progress: widget.progress,
        engine: widget.engine,
        schedule: widget.schedule,
        contentService: widget.contentService,
        audioService: widget.audioService,
      ),
    ));
    _busy = false;
    if (!mounted) return;
    setState(() {}); // reflect any level-up
    // Re-orient after the lesson — delayed so a goodbye or level-up line
    // finishes ringing first.
    _greetTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final p = widget.progress;
      widget.audioService.speak(p.pathComplete
          ? 'You did everything! Amazing!'
          : 'Level ${p.level}! Tap the big button to keep going!');
    });
  }

  /// The badge a room wears: the level's first pictured new symbol, its first
  /// new syllable in print, or a balloon for review rooms.
  String _badge(CurriculumLevel level) {
    for (final id in level.introduce) {
      final emoji = kPictographEmoji[id];
      if (emoji != null) return emoji;
    }
    if (level.introduce.isNotEmpty) return level.introduce.first;
    return '🎈'; // review room — a party, not new material
  }

  /// The theme lesson node [i] of [level] will carry (for its icon): the very
  /// next node uses live seen-intros; other nodes assume the meet lesson
  /// will have happened.
  LessonTheme _nodeTheme(CurriculumLevel level, int i) {
    final p = widget.progress;
    if (i == p.lessonsIntoLevel) {
      return LessonPlan.themeFor(
          level: level, seenIntros: p.seenIntros, lessonIndex: i);
    }
    if (i == 0 && level.introduce.isNotEmpty) return LessonTheme.meet;
    return LessonPlan.themeFor(
        level: level,
        seenIntros: {...p.seenIntros, ...level.introduce},
        lessonIndex: i);
  }

  static const Map<LessonTheme, String> _themeEmoji = {
    LessonTheme.meet: '👋',
    LessonTheme.sounds: '👂',
    LessonTheme.story: '📖',
    LessonTheme.reading: '📚',
  };

  static const Map<LessonTheme, String> _themeLine = {
    LessonTheme.meet: 'New friends!',
    LessonTheme.sounds: 'Listening games!',
    LessonTheme.story: 'Story time!',
    LessonTheme.reading: 'Reading games!',
  };

  void _speak(String line) => widget.audioService.speak(line);

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
                icon: Text(avatarEmoji(widget.profile!.avatar),
                    style: const TextStyle(fontSize: 24)),
              ),
        title: Text(widget.profile?.name ?? 'Reading Game'),
        actions: [
          IconButton(
            key: const Key('home-progress'),
            icon: const Icon(Icons.emoji_events),
            tooltip: 'My progress',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ProgressScreen(progress: widget.progress),
            )),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.progress,
          builder: (context, _) {
            final p = widget.progress;
            final level = widget.schedule.levelAt(p.level);
            final unit = widget.schedule.unitFor(p.level);
            return Column(
              children: [
                const SizedBox(height: 12),
                // ── Tier 1: the worlds ──
                _WorldStrip(
                  schedule: widget.schedule,
                  progress: p,
                  onTap: (u) {
                    if (u.id == unit.id) {
                      _speak('${u.title}! Tap the big button to play!');
                    } else if (u.levels.first > p.level) {
                      _speak('Locked! Keep playing to get to ${u.title}!');
                    } else {
                      _speak('You finished ${u.title}!');
                    }
                  },
                ),
                const SizedBox(height: 10),
                Text('${unit.emoji}  ${unit.title}',
                    key: const Key('home-world-title'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                // ── Tier 2: this world's rooms ──
                _RoomRow(
                  unit: unit,
                  progress: p,
                  badgeOf: (id) => _badge(widget.schedule.levelAt(id)),
                  onTap: (id) {
                    if (id == p.level) {
                      _speak('${widget.schedule.levelAt(id).title}! '
                          'Tap the big button to play!');
                    } else if (id > p.level) {
                      _speak('Locked! Keep playing to get there!');
                    } else {
                      _speak('You beat that one already!');
                    }
                  },
                ),
                const Spacer(),
                Text(level.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                // ── Tier 3: the lesson nodes ──
                if (p.pathComplete)
                  const Text('🏆', style: TextStyle(fontSize: 44))
                else
                  _LessonNodePath(
                    count: p.lessonsForThisLevel,
                    done: p.lessonsIntoLevel,
                    emojiOf: (i) => _themeEmoji[_nodeTheme(level, i)] ?? '⭐',
                    onTap: (i) {
                      if (i == p.lessonsIntoLevel) {
                        _openLesson();
                      } else if (i < p.lessonsIntoLevel) {
                        _speak('Done!');
                      } else {
                        _speak(_themeLine[_nodeTheme(level, i)] ?? 'Soon!');
                      }
                    },
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  height: 84,
                  child: FilledButton(
                    key: const Key('home-play'),
                    onPressed: _openLesson,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 52),
                  ),
                ),
                const Spacer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Tier 1: every world as an emoji landmark — done worlds glow, the current
/// world wears a progress ring, future worlds wait faded with a little lock.
class _WorldStrip extends StatelessWidget {
  const _WorldStrip({
    required this.schedule,
    required this.progress,
    required this.onTap,
  });

  final CurriculumSchedule schedule;
  final ProgressService progress;
  final ValueChanged<CurriculumUnit> onTap;

  double _fraction(CurriculumUnit u) {
    final done = u.levels.where((l) => l < progress.level).length;
    final inCurrent = u.levels.contains(progress.level)
        ? progress.levelFraction
        : 0.0;
    return ((done + inCurrent) / u.levels.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final units = schedule.units.isEmpty
        ? [schedule.unitFor(progress.level)]
        : schedule.units;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const SizedBox(width: 16),
          for (final u in units) ...[
            GestureDetector(
              key: Key('world-${u.id}'),
              onTap: () => onTap(u),
              child: _buildLandmark(context, scheme, u),
            ),
            const SizedBox(width: 10),
          ],
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildLandmark(
      BuildContext context, ColorScheme scheme, CurriculumUnit u) {
    final current = u.levels.contains(progress.level);
    final done = u.levels.every((l) => l < progress.level) ||
        (progress.pathComplete && u.levels.contains(progress.level));
    final locked = !current && !done;

    final face = Container(
      width: current ? 52 : 44,
      height: current ? 52 : 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? scheme.primaryContainer
            : current
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
      ),
      child: Opacity(
        opacity: locked ? 0.4 : 1,
        child: Text(u.emoji, style: TextStyle(fontSize: current ? 26 : 22)),
      ),
    );

    final Widget marked = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        face,
        if (done)
          const Positioned(
              right: -2,
              bottom: -2,
              child: Icon(Icons.star, color: Colors.amber, size: 16)),
        if (locked)
          Positioned(
              right: -2,
              bottom: -2,
              child: Icon(Icons.lock, color: scheme.outline, size: 14)),
      ],
    );

    if (!current) return marked;
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: _fraction(u),
              strokeWidth: 4,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          marked,
        ],
      ),
    );
  }
}

/// Tier 2: the current world's rooms, each wearing the symbol it teaches
/// (or a balloon for its review party).
class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.unit,
    required this.progress,
    required this.badgeOf,
    required this.onTap,
  });

  final CurriculumUnit unit;
  final ProgressService progress;
  final String Function(int levelId) badgeOf;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final id in unit.levels) ...[
          GestureDetector(
            key: Key('room-$id'),
            onTap: () => onTap(id),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: id == progress.level
                        ? scheme.primaryContainer
                        : id < progress.level
                            ? scheme.primaryContainer.withValues(alpha: 0.6)
                            : scheme.surfaceContainerHighest,
                    border: id == progress.level
                        ? Border.all(color: scheme.primary, width: 3)
                        : null,
                  ),
                  child: Opacity(
                    opacity: id > progress.level ? 0.4 : 1,
                    child: Text(badgeOf(id),
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                if (id < progress.level)
                  const Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(Icons.check_circle,
                          color: Colors.green, size: 16)),
                if (id > progress.level)
                  Positioned(
                      right: -2,
                      bottom: -2,
                      child:
                          Icon(Icons.lock, color: scheme.outline, size: 14)),
              ],
            ),
          ),
          if (id != unit.levels.last)
            Container(
              width: 18,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: id < progress.level
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ],
    );
  }
}

/// Tier 3: this room's lesson nodes on a little trail — each node's emoji
/// says what kind of lesson it is; the next one up glows.
class _LessonNodePath extends StatelessWidget {
  const _LessonNodePath({
    required this.count,
    required this.done,
    required this.emojiOf,
    required this.onTap,
  });

  final int count;
  final int done;
  final String Function(int index) emojiOf;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('home-nodes'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          GestureDetector(
            key: Key('lesson-node-$i'),
            onTap: () => onTap(i),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: i == done ? 64 : 54,
                  height: i == done ? 64 : 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < done
                        ? scheme.primary
                        : i == done
                            ? scheme.primaryContainer
                            : scheme.surfaceContainerHighest,
                    border: i == done
                        ? Border.all(color: scheme.primary, width: 3)
                        : null,
                  ),
                  child: Opacity(
                    opacity: i > done ? 0.45 : 1,
                    child: Text(emojiOf(i),
                        style: TextStyle(fontSize: i == done ? 28 : 24)),
                  ),
                ),
                if (i < done)
                  Positioned(
                      right: -2,
                      bottom: -2,
                      child: Icon(Icons.check_circle,
                          color: Colors.green.shade600, size: 20)),
              ],
            ),
          ),
          if (i != count - 1)
            Container(
              width: 22,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i < done ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ],
    );
  }
}
