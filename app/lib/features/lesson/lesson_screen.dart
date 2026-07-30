import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../learning/curriculum_engine.dart';
import '../../learning/item_sampler.dart';
import '../../learning/lesson_plan.dart';
import '../../models/content_bank.dart';
import '../../models/curriculum.dart';
import '../../progress/learning_event.dart';
import '../../progress/progress_service.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../blend_reveal/blend_reveal_page.dart';
import '../build_a_word/build_a_word_page.dart';
import '../common/guide_character.dart';
import '../echo_read/echo_read_page.dart';
import '../families/families_page.dart';
import '../fill_blank/fill_blank_page.dart';
import '../find_the_character/find_the_character_page.dart';
import '../home/introduce_symbol_screen.dart';
import '../home/level_up_overlay.dart';
import '../listen_and_pick/listen_and_pick_page.dart';
import '../picture_to_word/picture_to_word_page.dart';
import '../sound_match/sound_match_page.dart';
import '../symbol_hunt/symbol_hunt_page.dart';
import 'celebration.dart';

/// One **lesson**: a short, finite run of mixed single-round exercises with a
/// segmented progress bar, a guide character reacting to every answer, and a
/// starred celebration at the end (see docs/lessons.md). Steps auto-advance;
/// missed exercises are re-queued once near the end; leaving early keeps all
/// recorded progress — the lesson simply doesn't count.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
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
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const int _requeueCap = 2;

  late final Random _random = widget.random ?? Random();
  late final int _level;
  late final Guide _guide;
  late final ItemSampler _sampler;
  late final List<LessonStep> _steps;

  int _index = 0;
  int _wrongTotal = 0;
  int _requeues = 0;
  String? _missedThisStep;
  bool _celebrating = false;
  bool _allowPop = false;
  bool _letFarewellRing = false;
  GuideMood _mood = GuideMood.idle;
  Timer? _moodTimer;

  @override
  void initState() {
    super.initState();
    _level = widget.progress.level;
    _guide = guideForLevel(_level);
    _sampler = ItemSampler(widget.progress);
    _steps = List.of(LessonPlan.build(
      level: widget.schedule.levelAt(_level),
      seenIntros: widget.progress.seenIntros,
      random: _random,
    ));
    // Drain any stale level-up queue so a previous flow can never replay its
    // celebrations inside (or after) this lesson.
    widget.progress.takeJustLeveledUp();
  }

  @override
  void dispose() {
    _moodTimer?.cancel();
    // Cut any in-flight speech so game audio never bleeds onto the home
    // screen — unless we just said goodbye, which SHOULD ring out.
    if (!_letFarewellRing) widget.audioService.stop();
    super.dispose();
  }

  SyllableElement _element(String id) =>
      widget.engine.bank.elements.firstWhere((e) => e.id == id);

  // ── guide reactions ──
  void _setMood(GuideMood mood) {
    _moodTimer?.cancel();
    setState(() => _mood = mood);
    _moodTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _mood = GuideMood.idle);
    });
  }

  /// Every game answer flows through here: record it, animate the guide.
  void _onEvent(LearningEvent e) {
    widget.progress.record(e);
    if (e.correct) {
      _setMood(GuideMood.happy);
    } else {
      _wrongTotal++;
      _missedThisStep = e.itemId;
      _setMood(GuideMood.sad);
    }
  }

  // ── step flow ──
  void _stepDone({required bool flawless}) {
    final step = _steps[_index];
    if (!flawless && _requeues < _requeueCap && step is ExerciseStep) {
      // "Let's try that one again" — same game, focused on the missed item.
      _steps.add(ExerciseStep(step.gameId,
          focusId: _missedThisStep ?? step.focusId));
      _requeues++;
    }
    _missedThisStep = null;
    _advance();
  }

  void _introDone(String id) {
    widget.progress.markIntroSeen(id);
    _advance();
  }

  void _advance() {
    if (_index + 1 < _steps.length) {
      setState(() => _index++);
    } else {
      _finishLesson();
    }
  }

  int get _stars => _wrongTotal == 0 ? 3 : (_wrongTotal <= 2 ? 2 : 1);

  Future<void> _finishLesson() async {
    widget.progress.completeLesson();
    await widget.progress.flush();
    if (!mounted) return;
    // Let the child SEE the bar hit the end — the finish line paying off is
    // the whole point of showing one — then celebrate.
    setState(() => _index = _steps.length);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _celebrating = true);
  }

  Future<void> _celebrationDone() async {
    final reached = widget.progress.takeJustLeveledUp();
    if (reached.isNotEmpty && mounted) {
      widget.audioService.speak('Level ${reached.last}! New friends to meet!');
      await showLevelUp(
        context,
        level: widget.schedule.levelAt(reached.last),
        newSymbols: [
          for (final lv in reached)
            for (final id in widget.schedule.levelAt(lv).introduce)
              _element(id),
        ],
      );
    }
    _pop();
  }

  // ── leaving ──
  Future<void> _exit() async {
    widget.audioService.speak('Do you want to stop?');
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => const _LeaveDialog(),
    );
    if (!mounted) return;
    if (leave != true) {
      // Confirm the choice aloud so the dialog closing isn't a silent
      // mystery, and the distracted child re-engages.
      widget.audioService.speak('Keep going!');
      return;
    }
    _letFarewellRing = true;
    widget.audioService.speak('Bye bye! See you soon!');
    // Progress earned so far stays — only the lesson itself doesn't count.
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

  // ── step widgets ──
  Widget _buildStep(LessonStep step) {
    final allowed = widget.engine.introducedThrough(_level);
    final stage = widget.schedule.levelAt(_level).stage;
    final cs = widget.contentService;
    final audio = widget.audioService;

    switch (step) {
      case IntroStep(:final symbolId):
        return IntroduceSymbolScreen(
          key: ValueKey('step-$_index'),
          element: _element(symbolId),
          audioService: audio,
          onDone: () => _introDone(symbolId),
          embedded: true,
        );
      case ExerciseStep(:final gameId, :final focusId):
        final key = ValueKey('step-$_index');
        void done({required bool flawless}) => _stepDone(flawless: flawless);
        switch (gameId) {
          case 'listen_and_pick':
            return ListenAndPickPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'sound_match':
            return SoundMatchPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'families':
            return FamiliesPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'build_a_word':
            return BuildAWordPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'fill_blank':
            return FillBlankPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, stage: stage, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'picture_to_word':
            return PictureToWordPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'symbol_hunt':
            return SymbolHuntPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'echo_read':
            return EchoReadPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, stage: stage, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'blend_reveal':
            return BlendRevealPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
          case 'find_the_character':
          default:
            return FindTheCharacterPage(key: key, contentService: cs, audioService: audio, sampler: _sampler, allowedIds: allowed, embedded: true, onEvent: _onEvent, singleRound: true, focusId: focusId, onRoundComplete: done);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        body: SafeArea(
          child: _celebrating
              ? CelebrationView(
                  stars: _stars,
                  guide: _guide,
                  audioService: widget.audioService,
                  onContinue: _celebrationDone,
                )
              : Column(
                  children: [
                    // Kid-sized header: close, segmented progress, the guide.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            key: const Key('session-exit'),
                            iconSize: 28,
                            icon: const Icon(Icons.close_rounded),
                            color: scheme.outline,
                            tooltip: 'Stop',
                            onPressed: _exit,
                          ),
                          Expanded(
                            child: LessonProgressBar(
                              total: _steps.length,
                              done: _index,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GuideCharacter(guide: _guide, mood: _mood),
                        ],
                      ),
                    ),
                    // During the brief full-bar beat before the celebration,
                    // _index sits past the last step — show calm, not a step.
                    Expanded(
                      child: _index < _steps.length
                          ? _buildStep(_steps[_index])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The lesson's finish line, always visible: one rounded segment per step,
/// filling left to right with a springy pop as each is completed.
class LessonProgressBar extends StatelessWidget {
  const LessonProgressBar({super.key, required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              height: i < done ? 12 : 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: i < done ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }
}

/// Icon-first "stop playing?" dialog — spoken aloud when opened; the buttons
/// are pictures, not words: ▶ keep going (big, primary), 🚪 leave (small).
class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🛑', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Keep playing — the big, obvious, happy choice.
                SizedBox(
                  width: 120,
                  height: 88,
                  child: FilledButton(
                    key: const Key('session-stay'),
                    onPressed: () => Navigator.pop(context, false),
                    child: const Icon(Icons.play_arrow_rounded, size: 52),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 88,
                  height: 88,
                  child: OutlinedButton(
                    key: const Key('session-leave'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Icon(Icons.waving_hand_rounded,
                        size: 36, color: scheme.outline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
