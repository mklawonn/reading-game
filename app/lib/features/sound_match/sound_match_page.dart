import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/pictograph_emoji.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Sound-Match** (Stages 1–2): the child drags each symbol (pictograph/glyph)
/// onto **the sound it makes**; tapping a sound chip plays it. This directly
/// exercises the symbol→sound link the whole method rests on, and "did the right
/// symbol go to the right sound" is a clean per-item progress signal.
///
/// A later sub-phase extends this to Stage-4 letters where a multi-letter
/// grapheme maps to one phoneme (needs a grapheme→phoneme map in the bank).
class SoundMatchPage extends StatefulWidget {
  const SoundMatchPage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.setSize = 3,
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

  /// Number of symbol↔sound pairs per round.
  final int setSize;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven choice of the round's focus item. Null → uniform random.
  final ItemSampler? sampler;

  /// Restricts the pool to these element ids (curriculum's introduced symbols).
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each drop (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer this element as the round's focus item.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong drops.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<SoundMatchPage> createState() => _SoundMatchPageState();
}

class _SoundMatchPageState extends State<SoundMatchPage> with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  List<SyllableElement> _symbols = const []; // top row (draggable)
  List<SyllableElement> _sounds = const []; // bottom row (drag targets)
  final Set<String> _matched = {};
  String? _wrongSoundId;
  String? _primaryId; // previous round's focus item, to avoid immediate repeats
  int _score = 0;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    // Symbols that can be both shown and heard: the picturable stage-1 set,
    // scoped to the curriculum's introduced symbols when provided.
    _pool = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    if (_pool.length >= 2) {
      setState(_startRound);
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  static const _instruction = 'Match each picture to the sound it makes.';
  void _speakInstruction() => widget.audioService.speak(_instruction);

  SyllableElement? _focusElement() {
    if (_primaryId != null) return null; // first round only
    for (final e in _pool) {
      if (e.id == widget.focusId) return e;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    final n = min(widget.setSize, _pool.length);
    // The lesson's focus item wins; else mastery picks the round's focus item;
    // the rest fill in around it.
    final primary = _focusElement() ??
        widget.sampler?.pick<SyllableElement>(
          _pool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _primaryId,
        ) ??
        _pool[_random.nextInt(_pool.length)];
    _primaryId = primary.id;
    final rest = [..._pool]
      ..removeWhere((e) => e.id == primary.id)
      ..shuffle(_random);
    // Never seat look-alike pictures in one matching board (dog vs pup, …).
    final round = fillVisuallyDistinct([primary], rest, n, (e) => e.id);
    // Shuffle the two columns independently so positions don't line up.
    _symbols = [...round]..shuffle(_random);
    _sounds = [...round]..shuffle(_random);
    _matched.clear();
    _wrongSoundId = null;
  }

  bool get _solved =>
      _symbols.isNotEmpty && _matched.length == _symbols.length;

  void _onDrop(SyllableElement symbol, SyllableElement sound) {
    if (_matched.contains(symbol.id)) return;
    final correct = symbol.id == sound.id;
    widget.onEvent?.call(LearningEvent(
      itemId: symbol.id,
      skill: 'match',
      stage: symbol.introducedStage,
      correct: correct,
      game: 'sound_match',
    ));
    setState(() {
      if (correct) {
        _matched.add(symbol.id);
        _wrongSoundId = null;
        if (_solved) _score += 1;
      } else {
        noteWrongAttempt();
        _wrongSoundId = sound.id;
      }
    });
    if (correct) {
      // Finishing the whole board is the effortful win — celebrate it aloud.
      final speech = widget.audioService.speak(_solved
          ? '${symbol.syllable}! All matched — great job!'
          : '${symbol.syllable}!');
      if (_solved) {
        scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
      }
    } else {
      widget.audioService
          .speak('Oops! That sound is ${sound.syllable}. Try another one!');
    }
  }

  /// Any drop that missed every target still answers the child aloud —
  /// silence after an honest near-miss reads as "the game is broken".
  void _onDragMissed() {
    widget.audioService.speak('Almost! Drop it on a sound.');
  }

  void _next() {
    setState(_startRound);
    _speakInstruction();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: const Text('Sound Match'),
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
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Drag each picture to the sound it makes',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  // Draggable symbols (full width ⇒ centering is unconditional).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                      for (final e in _symbols)
                        if (_matched.contains(e.id))
                          _SymbolChip(element: e, faded: true)
                        else
                          Draggable<SyllableElement>(
                            key: Key('sm-symbol-${e.id}'),
                            data: e,
                            // A fresh attempt clears any lingering "wrong" red.
                            onDragStarted: () =>
                                setState(() => _wrongSoundId = null),
                            onDragEnd: (details) {
                              if (!details.wasAccepted) _onDragMissed();
                            },
                            feedback: Material(
                                color: Colors.transparent,
                                child: _SymbolChip(element: e)),
                            childWhenDragging:
                                _SymbolChip(element: e, faded: true),
                            child: GestureDetector(
                              onTap: () =>
                                  widget.audioService.speak(e.syllable),
                              child: _SymbolChip(element: e),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Keep the two rows close: a full-screen drag is beyond
                  // little arms and thumbs.
                  const SizedBox(height: 20),
                  // Sound targets (tap to hear, drop a symbol to match).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final e in _sounds)
                          _SoundChip(
                            key: Key('sm-sound-${e.id}'),
                            element: e,
                            matched: _matched.contains(e.id),
                            wrong: _wrongSoundId == e.id,
                            onTap: () => widget.audioService.speak(e.syllable),
                            // Hovering a chip while dragging plays its sound —
                            // the child never has to pre-memorize the mapping.
                            onHover: () =>
                                widget.audioService.speak(e.syllable),
                            onAccept: (symbol) => _onDrop(symbol, e),
                          ),
                      ],
                    ),
                  ),
                  // Fixed-height slot keeps the board steady when it appears.
                  FeedbackSlot(
                    child: _solved
                        ? Text('🎉 All matched!',
                            key: const Key('sm-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : null,
                  ),
                  const Spacer(),
                  // Big, always-present advance arrow — only tappable once
                  // solved. Lesson steps auto-advance instead, so no arrow.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('sm-next'),
                      enabled: _solved,
                      onNext: _next,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SymbolChip extends StatelessWidget {
  const _SymbolChip({required this.element, this.faded = false});

  final SyllableElement element;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.25 : 1,
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: GlyphView(element, size: 56),
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  const _SoundChip({
    super.key,
    required this.element,
    required this.matched,
    required this.wrong,
    required this.onTap,
    required this.onHover,
    required this.onAccept,
  });

  final SyllableElement element;
  final bool matched;
  final bool wrong;
  final VoidCallback onTap;

  /// A dragged symbol entered this target — play the sound it stands for.
  final VoidCallback onHover;
  final ValueChanged<SyllableElement> onAccept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<SyllableElement>(
      onWillAcceptWithDetails: (details) {
        if (!matched) onHover();
        return true;
      },
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        final color = matched || highlight
            ? scheme.primaryContainer
            : wrong
                ? scheme.errorContainer
                : scheme.surfaceContainerHighest;
        return GestureDetector(
          onTap: onTap,
          // The invisible margin widens the drop zone: a near-miss from a
          // wobbly little hand still lands.
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant, width: 2),
              ),
              // Once matched, the chip shows the symbol it captured.
              child: matched
                  ? GlyphView(element, size: 48)
                  : Icon(Icons.volume_up,
                      size: 36, color: scheme.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}
