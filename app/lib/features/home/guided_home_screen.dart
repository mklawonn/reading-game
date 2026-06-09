import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/curriculum.dart';
import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../build_a_word/build_a_word_page.dart';
import '../families/families_page.dart';
import '../fill_blank/fill_blank_page.dart';
import '../find_the_character/find_the_character_page.dart';
import '../listen_and_pick/listen_and_pick_page.dart';
import '../profile/avatars.dart';
import '../progress/level_map_screen.dart';
import '../progress/progress_screen.dart';
import '../sound_match/sound_match_page.dart';
import 'introduce_symbol_screen.dart';
import 'level_up_overlay.dart';

/// The guided home: a level path the child can't skip ahead on, and one **Play**
/// button that runs the curriculum's next activity — a Meet-the-symbol intro for
/// any new symbol, else a game scoped to the symbols taught so far. Reaching a
/// level's XP goal pops the level-up celebration.
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
  late final ItemSampler _sampler = ItemSampler(widget.progress);
  String? _lastGame;
  bool _busy = false;

  SyllableElement _element(String id) =>
      widget.engine.bank.elements.firstWhere((e) => e.id == id);

  Future<void> _play() async {
    if (_busy) return;
    _busy = true;
    final p = widget.progress;
    final activity = widget.engine.next(p.level, p.seenIntros, lastGame: _lastGame);

    if (activity is IntroduceActivity) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => IntroduceSymbolScreen(
          element: _element(activity.symbolId),
          audioService: widget.audioService,
          onDone: () {
            widget.progress.markIntroSeen(activity.symbolId);
            Navigator.of(context).pop();
          },
        ),
      ));
    } else if (activity is GameActivity) {
      _lastGame = activity.gameId;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _game(activity.gameId),
      ));
    }

    _busy = false;
    if (mounted) await _celebrateLevelUps();
  }

  Future<void> _celebrateLevelUps() async {
    for (final lv in widget.progress.takeJustLeveledUp()) {
      if (!mounted) return;
      final level = widget.schedule.levelAt(lv);
      await showLevelUp(
        context,
        level: level,
        newSymbols: [for (final id in level.introduce) _element(id)],
      );
    }
  }

  Widget _game(String gameId) {
    final p = widget.progress;
    final allowed = widget.engine.introducedThrough(p.level);
    final cs = widget.contentService;
    final audio = widget.audioService;
    switch (gameId) {
      case 'listen_and_pick':
        return ListenAndPickPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, onEvent: p.record);
      case 'sound_match':
        return SoundMatchPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, onEvent: p.record);
      case 'families':
        return FamiliesPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, onEvent: p.record);
      case 'build_a_word':
        return BuildAWordPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, onEvent: p.record);
      case 'fill_blank':
        return FillBlankPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, stage: p.curriculumStage, onEvent: p.record);
      case 'find_the_character':
      default:
        return FindTheCharacterPage(
            contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, onEvent: p.record);
    }
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
                  onPressed: _play,
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
