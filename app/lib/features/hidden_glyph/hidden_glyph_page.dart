import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/pictograph_emoji.dart';
import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Hidden Glyph**: an I-Spy search scene — glyphs are scattered playfully
/// across the board at varied sizes and slight rotations, and the child must
/// FIND the two hidden copies of the target word's picture. The written word
/// is shown (print exposure) and named aloud, so searching is the challenge,
/// not decoding.
class HiddenGlyphPage extends StatefulWidget {
  const HiddenGlyphPage({
    super.key,
    required this.contentService,
    required this.audioService,
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

  /// Inject a seeded [Random] in tests for determinism (it also drives the
  /// scene layout: positions, sizes, and rotations).
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
  State<HiddenGlyphPage> createState() => HiddenGlyphPageState();
}

/// One scattered glyph in the scene, placed fractionally so the layout can be
/// resolved against any board size without consuming more randomness.
class _SceneGlyph {
  const _SceneGlyph({
    required this.element,
    required this.cell,
    required this.jitterX,
    required this.jitterY,
    required this.size,
    required this.angle,
  });

  final SyllableElement element;

  /// Which of the 3×5 grid cells this glyph occupies (0..14, one cell of the
  /// board stays empty each round).
  final int cell;

  /// Offset from the cell origin, as a fraction of the cell (0..0.3).
  final double jitterX;
  final double jitterY;

  final double size;

  /// Slight tilt in radians — playful, but still recognizable.
  final double angle;
}

class HiddenGlyphPageState extends State<HiddenGlyphPage>
    with SingleRoundFlow<HiddenGlyphPage> {
  static const int _columns = 3;
  static const int _rows = 5;

  /// Scene glyphs per round: 14 of the 15 grid cells are used.
  static const int _slotCount = 14;

  /// How many hidden copies of the target are in the scene.
  static const int _targetCopies = 2;

  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  SyllableElement? _target;
  List<_SceneGlyph> _scene = const [];
  final Set<int> _found = {};
  bool _wrong = false;
  bool _wrongEventSent = false;
  bool _firstRound = true;
  int _score = 0;

  bool get _complete => _target != null && _found.length == _targetCopies;

  /// Element id per scene index — lets tests locate the hidden copies on the
  /// board without depending on layout.
  @visibleForTesting
  List<String> get glyphIds => [for (final g in _scene) g.element.id];

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _pool = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    if (_pool.length >= 4) {
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

    // Exactly 2 hidden copies of the target; the other 12 slots are random
    // OTHER symbols — duplicates among the decoys are fine, but a look-alike
    // of the target (dog vs pup, …) would make the search unfair.
    var others = _pool
        .where((e) =>
            e.id != target!.id && !confusablePictographs(e.id, target.id))
        .toList(growable: false);
    if (others.isEmpty) {
      // Degenerate pool (every other symbol is a look-alike): better an
      // unfair-ish board than a crash — real curricula never hit this.
      others = _pool.where((e) => e.id != target!.id).toList(growable: false);
    }
    final elements = [
      for (var i = 0; i < _targetCopies; i++) target,
      for (var i = _targetCopies; i < _slotCount; i++)
        others[_random.nextInt(others.length)],
    ]..shuffle(_random);

    // Scatter across a jittered 3×5 grid: one cell (chosen at random) stays
    // empty, and each glyph gets its own nudge, size, and tilt. All of it is
    // drawn from the injected Random, so a seeded test sees a fixed scene.
    final skipped = _random.nextInt(_columns * _rows);
    _scene = [
      for (var i = 0; i < _slotCount; i++)
        _SceneGlyph(
          element: elements[i],
          cell: i < skipped ? i : i + 1,
          jitterX: _random.nextDouble() * 0.3,
          jitterY: _random.nextDouble() * 0.3,
          size: 44 + _random.nextDouble() * 28,
          angle: (_random.nextDouble() - 0.5) * 0.7,
        ),
    ];
    _target = target;
    _found.clear();
    _wrong = false;
    _wrongEventSent = false;
  }

  /// Spoken on load and on each new round — names the task aloud so a
  /// pre-reader always knows what to do without tapping anything.
  void _speakInstruction() {
    final target = _target;
    if (target != null) {
      widget.audioService.speak('Look everywhere! Find the ${target.syllable}!');
    }
  }

  void _onTapGlyph(int index) {
    // Round over, or this copy is already found — ignore the tap.
    if (_complete || _found.contains(index)) return;
    final target = _target!;
    final element = _scene[index].element;
    if (element.id == target.id) {
      setState(() {
        _found.add(index);
        _wrong = false;
        if (_complete) _score += 1;
      });
      // The last find is the win — say so, out loud, as ONE utterance (and
      // let it finish: the advance waits for this speech).
      final speech = widget.audioService.speak(_complete
          ? '${target.syllable}! You found them!'
          : target.syllable);
      if (_complete) {
        // One event per round — the search is a single recognition exercise.
        widget.onEvent?.call(LearningEvent(
          itemId: target.id,
          skill: 'recognize',
          stage: target.introducedStage,
          correct: true,
          game: 'hidden_glyph',
        ));
        scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
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
          game: 'hidden_glyph',
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
        title: const Text('Hidden Glyph'),
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
          if (_pool.length < 4) {
            return const Center(child: Text('Not enough to play.'));
          }
          final target = _target!;
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Two are hiding — find them!',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // The hunted word in print, with audio support. The leading
                // box mirrors the IconButton so the word itself is centered.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    SyllableTile(target.syllable, fontSize: 30),
                    IconButton(
                      key: const Key('hg-hear'),
                      onPressed: _speakInstruction,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Hear it',
                    ),
                  ],
                ),
                // Fixed-height slot: feedback never shoves the scene around.
                FeedbackSlot(
                  child: _complete
                      ? Text('🎉 Found them!',
                          key: const Key('hg-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — keep looking!',
                              key: const Key('hg-wrong'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                          : null,
                ),
                // The search scene: a Stack over a jittered grid. Each glyph
                // keeps its exact box forever — a found copy swaps its CONTENT
                // to a star, so nothing ever reflows mid-hunt.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellW = constraints.maxWidth / _columns;
                        final cellH = constraints.maxHeight / _rows;
                        return Stack(
                          children: [
                            for (var i = 0; i < _scene.length; i++)
                              _positionedGlyph(i, cellW, cellH, target),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                // Big, always-present advance arrow — only tappable once both
                // copies are found. A lesson step advances itself instead.
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('hg-next'),
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

  Widget _positionedGlyph(
      int index, double cellW, double cellH, SyllableElement target) {
    final g = _scene[index];
    final found = _found.contains(index);
    final dimmed = _complete && g.element.id != target.id;
    return Positioned(
      left: (g.cell % _columns) * cellW + g.jitterX * cellW,
      top: (g.cell ~/ _columns) * cellH + g.jitterY * cellH,
      child: GestureDetector(
        key: Key('hg-glyph-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTapGlyph(index),
        // The box never changes size or position: found copies and end-of-
        // round dimming only swap/paint content inside it.
        child: SizedBox(
          width: g.size,
          height: g.size,
          child: Center(
            child: found
                // The pop: a star painted slightly LARGER than the glyph was,
                // without touching layout (Transform paints, never reflows).
                ? Transform.scale(
                    scale: 1.3,
                    child: Text('⭐', style: TextStyle(fontSize: g.size * 0.82)),
                  )
                : Opacity(
                    opacity: dimmed ? 0.35 : 1,
                    child: Transform.rotate(
                      angle: g.angle,
                      child: GlyphView(g.element, size: g.size),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
