import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Symbol Hunt**: an I-Spy game — the narrator asks "Find all the cats!" and
/// the child taps EVERY copy of the target symbol in a grid that also contains
/// other symbols. Multi-tap and playful, and it works from the very first
/// level because it only needs 2 distinct symbols.
class SymbolHuntPage extends StatefulWidget {
  const SymbolHuntPage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.gridSize = 6,
    this.random,
    this.sampler,
    this.allowedIds,
    this.embedded = false,
    this.onEvent,
    this.singleRound = false,
    this.focusId,
    this.onRoundComplete,
  });

  final ContentService contentService;
  final AudioService audioService;

  /// Number of cells on the hunt board.
  final int gridSize;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven target selection. When null, falls back to uniform random
  /// (keeps widget tests deterministic via [random]).
  final ItemSampler? sampler;

  /// Restricts the pool to these element ids (the curriculum's introduced
  /// symbols). Null = no restriction.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round and auto-advance via
  /// [onRoundComplete] instead of showing the "next" arrow.
  final bool singleRound;

  /// The element the first round should target, when present in the pool.
  final String? focusId;

  /// Reports a completed round (and whether it was flawless) to the host.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<SymbolHuntPage> createState() => SymbolHuntPageState();
}

class SymbolHuntPageState extends State<SymbolHuntPage>
    with SingleRoundFlow<SymbolHuntPage> {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  SyllableElement? _target;
  List<SyllableElement> _cells = const [];
  int _targetCount = 0;
  final Set<int> _found = {};
  bool _wrong = false;
  bool _wrongEventSent = false;
  bool _firstRound = true;
  int _score = 0;

  bool get _complete => _target != null && _found.length == _targetCount;

  /// Element id per cell index — lets tests locate the target cells on the
  /// board without depending on layout.
  @visibleForTesting
  List<String> get cellIds => [for (final e in _cells) e.id];

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _pool = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    if (_pool.length >= 2) {
      _startRound();
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  void _startRound() {
    resetRoundFlaws();
    // The first round honors the lesson's focus symbol; afterwards mastery
    // steers the target (uniform random when no sampler is injected).
    SyllableElement? target;
    if (_firstRound && widget.focusId != null) {
      for (final e in _pool) {
        if (e.id == widget.focusId) target = e;
      }
    }
    target ??= widget.sampler?.pick<SyllableElement>(
          _pool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _target?.id,
        ) ??
        _pool[_random.nextInt(_pool.length)];
    _firstRound = false;

    // 2–3 copies of the target (never crowding out the distractors), the rest
    // random OTHER symbols — duplicates among the others are fine.
    final targetCount = min(2 + _random.nextInt(2), max(1, widget.gridSize - 2));
    final others = _pool.where((e) => e.id != target!.id).toList(growable: false);
    _cells = [
      for (var i = 0; i < targetCount; i++) target,
      for (var i = targetCount; i < widget.gridSize; i++)
        others[_random.nextInt(others.length)],
    ]..shuffle(_random);
    _target = target;
    _targetCount = targetCount;
    _found.clear();
    _wrong = false;
    _wrongEventSent = false;
  }

  /// Spoken on load and on each new round — names the task aloud so a
  /// pre-reader always knows what to do without tapping anything.
  void _speakInstruction() {
    final target = _target;
    if (target != null) {
      widget.audioService.speak('Find all the ${target.syllable}s!');
    }
  }

  void _onTapCell(int index) {
    // Round over, or this copy is already found — ignore the tap.
    if (_complete || _found.contains(index)) return;
    final target = _target!;
    final element = _cells[index];
    if (element.id == target.id) {
      setState(() {
        _found.add(index);
        _wrong = false;
        if (_complete) _score += 1;
      });
      // The last find is the win — say so, out loud.
      widget.audioService.speak(_complete
          ? '${target.syllable}! You found them all!'
          : target.syllable);
      if (_complete) {
        // One event per round — the hunt is a single recognition exercise.
        widget.onEvent?.call(LearningEvent(
          itemId: target.id,
          skill: 'recognize',
          stage: target.introducedStage,
          correct: true,
          game: 'symbol_hunt',
        ));
        scheduleRoundComplete(widget.onRoundComplete);
      }
    } else {
      noteWrongAttempt();
      // A distinct gentle miss that names what they actually tapped.
      widget.audioService.speak('Oops! That is the ${element.syllable}.');
      if (!_wrongEventSent) {
        // Only the FIRST wrong tap of a round demotes; don't spam the engine.
        _wrongEventSent = true;
        widget.onEvent?.call(LearningEvent(
          itemId: target.id,
          skill: 'recognize',
          stage: target.introducedStage,
          correct: false,
          game: 'symbol_hunt',
        ));
      }
      setState(() => _wrong = true);
    }
  }

  void _next() {
    setState(_startRound);
    _speakInstruction();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: const Text('Symbol Hunt'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text('⭐ $_score')),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_pool.length < 2) {
            return const Center(child: Text('Not enough symbols to play.'));
          }
          final target = _target!;
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Tap every one of these!',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // The hunted symbol, with audio support. The leading box
                // mirrors the IconButton so the symbol itself is centered.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    GlyphView(target, size: 48),
                    IconButton(
                      key: const Key('sh-hear'),
                      onPressed: _speakInstruction,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Hear it',
                    ),
                  ],
                ),
                // Fixed-height slot: feedback never shoves the board around.
                FeedbackSlot(
                  child: _complete
                      ? Text('🎉 Found them all!',
                          key: const Key('sh-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — keep hunting!',
                              key: const Key('sh-wrong'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                          : null,
                ),
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      for (var i = 0; i < _cells.length; i++)
                        _HuntCell(
                          key: Key('sh-cell-$i'),
                          element: _cells[i],
                          found: _found.contains(i),
                          dimmed: _complete && _cells[i].id != target.id,
                          onTap: () => _onTapCell(i),
                        ),
                    ],
                  ),
                ),
                // Big, always-present advance arrow — only tappable once every
                // copy is found. A lesson step advances itself instead.
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('sh-next'),
                      enabled: _complete,
                      onNext: _next,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HuntCell extends StatelessWidget {
  const _HuntCell({
    super.key,
    required this.element,
    required this.found,
    required this.dimmed,
    required this.onTap,
  });

  final SyllableElement element;

  /// This copy of the target has been tapped — it "pops" into a star.
  final bool found;

  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Material(
        color: found ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: found
                ? const Text('⭐', style: TextStyle(fontSize: 64))
                : GlyphView(element, size: 64),
          ),
        ),
      ),
    );
  }
}
