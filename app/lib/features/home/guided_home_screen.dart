import 'dart:async';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../lesson/lesson_screen.dart';
import '../profile/avatars.dart';
import '../progress/level_map_screen.dart';
import '../progress/progress_screen.dart';

/// The guided home: a level path the child can't skip ahead on (each node
/// wearing the symbol it teaches), lesson pips showing how far into the level
/// they are, and one big **Play** button that opens the next short lesson
/// (see [LessonScreen]).
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

  /// The badge a path node wears: the level's first pictured new symbol, else
  /// its first new syllable in print, else a star.
  String _badge(CurriculumLevel level) {
    for (final id in level.introduce) {
      final emoji = kPictographEmoji[id];
      if (emoji != null) return emoji;
    }
    return level.introduce.isNotEmpty ? level.introduce.first : '⭐';
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
            final badges = {
              for (final l in widget.schedule.levels) l.id: _badge(l),
            };
            return Column(
              children: [
                const SizedBox(height: 16),
                // The path is the prettiest thing on screen and WILL be
                // tapped: the current node plays, the rest answer aloud.
                LevelMap(
                  progress: p,
                  badges: badges,
                  onTapNode: (level) {
                    if (level == p.level) {
                      _openLesson();
                    } else if (level > p.level) {
                      widget.audioService
                          .speak('Locked! Keep playing to get there!');
                    } else {
                      widget.audioService.speak('You beat that one already!');
                    }
                  },
                ),
                const Spacer(),
                Text('Level ${level.id}',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(level.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                // One pip per lesson in this level — tomorrow's "almost
                // there!" is legible to a child who can't read numbers yet.
                // Check-circles, not stars: stars are the lesson-quality
                // currency (celebration screen) and must mean only that.
                if (p.pathComplete)
                  const Text('🏆', style: TextStyle(fontSize: 34))
                else
                  Row(
                    key: const Key('home-pips'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < p.lessonsForThisLevel; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            i < p.lessonsIntoLevel
                                ? Icons.check_circle_rounded
                                : Icons.circle_outlined,
                            size: 30,
                            color: i < p.lessonsIntoLevel
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
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
