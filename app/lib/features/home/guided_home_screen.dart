import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../profile/avatars.dart';
import '../progress/level_map_screen.dart';
import '../progress/progress_screen.dart';
import 'level_session_screen.dart';

/// The guided home: a level path the child can't skip ahead on, and one **Play**
/// button that opens the current level as a single continuous session (see
/// [LevelSessionScreen]) — meet its symbols, then play until beaten or left.
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

  Future<void> _openLevel() async {
    if (_busy) return;
    _busy = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LevelSessionScreen(
        progress: widget.progress,
        engine: widget.engine,
        schedule: widget.schedule,
        contentService: widget.contentService,
        audioService: widget.audioService,
      ),
    ));
    _busy = false;
    if (mounted) setState(() {}); // reflect any level-up
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
            final span = p.xpForThisLevel;
            return Column(
              children: [
                const SizedBox(height: 16),
                LevelMap(progress: p),
                const Spacer(),
                Text('Level ${level.id}',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(level.title,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  width: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: span == 0 ? 0 : p.xpIntoLevel / span,
                      minHeight: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('home-play'),
                  onPressed: _openLevel,
                  icon: const Icon(Icons.play_arrow, size: 32),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: Text('Play', style: TextStyle(fontSize: 22)),
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
