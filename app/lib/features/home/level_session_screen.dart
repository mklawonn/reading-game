import 'dart:math';

import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/curriculum.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../build_a_word/build_a_word_page.dart';
import '../families/families_page.dart';
import '../fill_blank/fill_blank_page.dart';
import '../find_the_character/find_the_character_page.dart';
import '../listen_and_pick/listen_and_pick_page.dart';
import '../sound_match/sound_match_page.dart';
import 'introduce_symbol_screen.dart';
import 'level_up_overlay.dart';

/// One **continuous** level played in a single sitting: meet every new symbol,
/// then play the level's game until its XP goal is reached ("beaten" → celebrate
/// and keep the progress), or leave via the ✕ (which **discards** the whole
/// session — a level is completed all at once). Bite-sized by design.
class LevelSessionScreen extends StatefulWidget {
  const LevelSessionScreen({
    super.key,
    required this.progress,
    required this.engine,
    required this.schedule,
    required this.contentService,
    required this.audioService,
    this.random,
  });

  final ProgressService progress;
  final CurriculumEngine engine;
  final CurriculumSchedule schedule;
  final ContentService contentService;
  final AudioService audioService;
  final Random? random;

  @override
  State<LevelSessionScreen> createState() => _LevelSessionScreenState();
}

class _LevelSessionScreenState extends State<LevelSessionScreen> {
  late final Random _random = widget.random ?? Random();
  late final int _entryLevel;
  // Snapshot of progress on entry — restored if the child leaves early.
  late final Map<String, dynamic> _snapshot;
  late final ItemSampler _sampler;
  late final List<String> _intros;
  late final String _gameId;

  bool _ending = false;
  bool _allowPop = false;

  String _pickGame() {
    final games = widget.schedule.levelAt(_entryLevel).games;
    return games.isEmpty
        ? 'find_the_character'
        : games[_random.nextInt(games.length)];
  }

  @override
  void initState() {
    super.initState();
    // Capture entry state eagerly so an early exit can revert exactly to it.
    _entryLevel = widget.progress.level;
    _snapshot = widget.progress.toJson();
    _sampler = ItemSampler(widget.progress);
    _intros = List.of(
        widget.engine.pendingIntros(_entryLevel, widget.progress.seenIntros));
    _gameId = _pickGame();
    widget.progress.addListener(_onProgress);
  }

  @override
  void dispose() {
    widget.progress.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    if (!_ending && widget.progress.level > _entryLevel) {
      _ending = true;
      _beatLevel();
    }
  }

  SyllableElement _element(String id) =>
      widget.engine.bank.elements.firstWhere((e) => e.id == id);

  Future<void> _beatLevel() async {
    widget.progress.removeListener(_onProgress);
    await widget.progress.flush(); // commit the win
    for (final lv in widget.progress.takeJustLeveledUp()) {
      if (!mounted) return;
      final level = widget.schedule.levelAt(lv);
      await showLevelUp(
        context,
        level: level,
        newSymbols: [for (final id in level.introduce) _element(id)],
      );
    }
    _pop();
  }

  Future<void> _exit() async {
    if (_ending) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave this level?'),
        content: const Text("You'll start it from the beginning next time."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            key: const Key('session-leave'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    widget.progress.removeListener(_onProgress);
    widget.progress.loadJson(_snapshot); // discard this session's progress
    await widget.progress.flush();
    _pop();
  }

  // Pops past PopScope: flip canPop, then pop after the rebuild applies it.
  void _pop() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _introDone() {
    final id = _intros.removeAt(0);
    widget.progress.markIntroSeen(id);
    setState(() {});
  }

  Widget _game() {
    final p = widget.progress;
    final allowed = widget.engine.introducedThrough(p.level);
    final cs = widget.contentService;
    final audio = widget.audioService;
    switch (_gameId) {
      case 'listen_and_pick':
        return ListenAndPickPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: p.record);
      case 'sound_match':
        return SoundMatchPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: p.record);
      case 'families':
        return FamiliesPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: p.record);
      case 'build_a_word':
        return BuildAWordPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: p.record);
      case 'fill_blank':
        return FillBlankPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, stage: p.curriculumStage, onEvent: p.record);
      case 'find_the_character':
      default:
        return FindTheCharacterPage(contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: p.record);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final level = widget.schedule.levelAt(_entryLevel);
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: scheme.inversePrimary,
          leading: IconButton(
            key: const Key('session-exit'),
            icon: const Icon(Icons.close),
            tooltip: 'Leave level',
            onPressed: _exit,
          ),
          title: Text('Level ${level.id} · ${level.title}'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: ListenableBuilder(
              listenable: widget.progress,
              builder: (context, _) {
                final span = widget.progress.xpForThisLevel;
                return LinearProgressIndicator(
                  value: span == 0 ? 0 : widget.progress.xpIntoLevel / span,
                  minHeight: 6,
                );
              },
            ),
          ),
        ),
        body: SafeArea(
          child: _intros.isNotEmpty
              ? IntroduceSymbolScreen(
                  key: ValueKey(_intros.first),
                  element: _element(_intros.first),
                  audioService: widget.audioService,
                  onDone: _introDone,
                  embedded: true,
                )
              : _game(),
        ),
      ),
    );
  }
}
