import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../content/token_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/phrase.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/praise.dart';
import '../common/single_round.dart';

/// One scattered card. A sentence can repeat an element ('the ... the'), so a
/// piece is identified by a unique [token], never by its element id.
class _Piece {
  const _Piece(this.token, this.element);
  final int token;
  final SyllableElement element;
}

/// **Build a Sentence** — the productive counterpart of Echo Read and the
/// early gateway to combining glyphs. The child **hears** a short sentence
/// (never sees its print — the target lives in the ear), then arranges
/// scattered glyph cards into ordered slots to build it.
///
/// The sentence is a real authored phrase when the taught pool allows one;
/// otherwise a synthesized 3-token pictograph row (the Gleitman & Rozin
/// pictograph sentence) — so the game works from the earliest levels.
class BuildASentencePage extends StatefulWidget {
  const BuildASentencePage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.stage = 1,
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

  /// The child's current curriculum stage — drives how tokens are rendered.
  final int stage;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Kept for contract uniformity with the other games; Build a Sentence has
  /// no per-item drill choice (a whole phrase/row is the unit), so it is unused.
  final ItemSampler? sampler;

  /// Restricts phrases (and synthesized rows) to these introduced element ids.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each full-board check (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play one round, then auto-advance via [onRoundComplete]
  /// (no "next" arrow).
  final bool singleRound;

  /// Preferred element to include in a synthesized picture row, when provided.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong builds.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<BuildASentencePage> createState() => _BuildASentencePageState();
}

class _BuildASentencePageState extends State<BuildASentencePage>
    with SingleRoundFlow<BuildASentencePage> {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  /// Phrases longer than this would build an unmanageably wide slot row.
  static const int _maxTokens = 6;

  final Map<String, SyllableElement> _elementById = {};
  List<SyllableElement> _allElements = const [];
  List<SyllableElement> _picturablePool = const [];
  List<Phrase> _phrases = const [];

  /// The target token sequence — from a phrase or synthesized.
  List<SyllableElement> _tokens = const [];
  Phrase? _phrase; // null when the sequence was synthesized
  String? _prevPhraseId;
  List<_Piece> _scatter = [];
  List<_Piece?> _slots = [];
  int _nextToken = 0;
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  /// The fluent spoken form of the target sequence.
  String get _sentence => _tokens.map((e) => e.syllable).join(' ');

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _allElements = bank.elements;
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    _picturablePool = bank.elements
        .where(
            (e) => e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    final set = await widget.contentService.loadPhrases();
    // Usable = every token resolves, (if scoped) is introduced, and the phrase
    // is short enough to seat as a slot row.
    _phrases = set.phrases
        .where((p) =>
            p.tokens.length <= _maxTokens &&
            p.tokens.every(_elementById.containsKey) &&
            (widget.allowedIds == null ||
                p.tokens.every(widget.allowedIds!.contains)))
        .toList(growable: false);
    if (_phrases.isNotEmpty || _picturablePool.length >= 3) {
      setState(_startRound);
      _speakIntro();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  /// Spoken on each round start: the task instruction, then — chained after
  /// the instruction finishes (3s guard so wedged TTS can't stall the round) —
  /// the full target sentence the child must build from memory.
  void _speakIntro() {
    widget.audioService
        .speak('Listen! Build the sentence.')
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .then((_) {
      if (!mounted) return Future<void>.value();
      return _speakSentence();
    });
  }

  Future<void> _speakSentence() => widget.audioService.speak(_sentence);

  void _startRound() {
    resetRoundFlaws();
    if (_phrases.isNotEmpty) {
      // Avoid repeating the previous phrase when more than one is available.
      final fresh =
          _phrases.where((p) => p.id != _prevPhraseId).toList(growable: false);
      final pool = fresh.isNotEmpty ? fresh : _phrases;
      final phrase = pool[_random.nextInt(pool.length)];
      _prevPhraseId = phrase.id;
      _phrase = phrase;
      _tokens = [for (final id in phrase.tokens) _elementById[id]!];
    } else {
      _phrase = null;
      _tokens = _synthesizeSequence();
    }
    final pieces = <_Piece>[
      for (final e in _tokens) _Piece(_nextToken++, e),
    ];
    // One distractor piece to make ordering non-trivial — but never a
    // look-alike of a sentence token, and omitted when none qualifies.
    final distractor = _pickDistractor();
    if (distractor != null) pieces.add(_Piece(_nextToken++, distractor));
    pieces.shuffle(_random);
    _scatter = pieces;
    _slots = List<_Piece?>.filled(_tokens.length, null);
    _solved = false;
    _wrong = false;
  }

  /// Fallback for early levels with no usable phrase: a Gleitman & Rozin
  /// pictograph "sentence" of 3 distinct picturable symbols. The focus element
  /// is always included when provided, but the final order is shuffled so it
  /// doesn't always sit in slot 0.
  List<SyllableElement> _synthesizeSequence() {
    final pool = [..._picturablePool]..shuffle(_random);
    final chosen = <SyllableElement>[];
    if (widget.focusId != null) {
      final at = pool.indexWhere((e) => e.id == widget.focusId);
      if (at != -1) chosen.add(pool.removeAt(at));
    }
    fillVisuallyDistinct(chosen, pool, 3, (e) => e.id);
    chosen.shuffle(_random);
    return chosen;
  }

  /// An allowed element outside the sequence that is not visually confusable
  /// with any sentence token; null when no such element exists.
  SyllableElement? _pickDistractor() {
    final inSequence = {for (final e in _tokens) e.id};
    final candidates = _allElements
        .where((e) =>
            !inSequence.contains(e.id) &&
            (widget.allowedIds?.contains(e.id) ?? true) &&
            _tokens.every((t) => !confusablePictographs(t.id, e.id)))
        .toList()
      ..shuffle(_random);
    return candidates.isEmpty ? null : candidates.first;
  }

  void _placeInSlot(_Piece piece, int index) {
    if (_solved || _slots[index] != null) return;
    setState(() {
      _slots[index] = piece;
      _scatter.remove(piece);
      _wrong = false;
    });
    _check();
  }

  void _placeNext(_Piece piece) {
    final index = _slots.indexWhere((s) => s == null);
    if (index != -1) _placeInSlot(piece, index);
  }

  void _removeFromSlot(int index) {
    final piece = _slots[index];
    if (_solved || piece == null) return;
    setState(() {
      _slots[index] = null;
      _scatter.add(piece);
      _wrong = false;
    });
  }

  void _check() {
    if (_slots.any((s) => s == null)) return;
    final built = [for (final s in _slots) s!.element.id];
    final target = [for (final e in _tokens) e.id];
    final correct = _listEquals(built, target);
    widget.onEvent?.call(LearningEvent(
      itemId: _phrase?.answer ?? _tokens.first.id,
      skill: 'read',
      stage: widget.stage,
      correct: correct,
      game: 'build_a_sentence',
    ));
    setState(() {
      if (correct) {
        _solved = true;
        _score += 1;
      } else {
        noteWrongAttempt();
        _wrong = true;
      }
    });
    if (correct) {
      // Praise and the fluent sentence in ONE utterance, so the celebration
      // can't be cut in half by a lesson advance.
      final speech =
          widget.audioService.speak('${praiseLine(_random)} $_sentence!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      widget.audioService.speak('Not yet! Listen again: $_sentence');
    }
  }

  void _next() {
    setState(_startRound);
    _speakIntro();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Build a Sentence'),
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
          if (_tokens.isEmpty) {
            return const Center(child: Text('Nothing to build yet.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Listen, then build the sentence',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const Key('bs-hear'),
                    onPressed: _speakSentence,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Hear it'),
                  ),
                  const SizedBox(height: 16),
                  // Ordered slots. Scaled down (never reflowed) when a long
                  // phrase would overflow a narrow screen.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _slots.length; i++)
                          _Slot(
                            index: i,
                            piece: _slots[i],
                            stage: widget.stage,
                            onAccept: (piece) => _placeInSlot(piece, i),
                            onTap: () => _removeFromSlot(i),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fixed-height slot keeps the board steady when it appears.
                  FeedbackSlot(
                    child: _solved
                        ? Text('🎉 You built it!',
                            key: const Key('bs-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : _wrong
                            ? Text('Not yet — try again',
                                key: const Key('bs-wrong'),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))
                            : null,
                  ),
                  const Spacer(),
                  // Scattered, draggable pieces; tap seats the next empty slot.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final piece in _scatter)
                          _DraggablePiece(
                            key: Key('bs-piece-${piece.token}'),
                            piece: piece,
                            stage: widget.stage,
                            onTap: () => _placeNext(piece),
                          ),
                      ],
                    ),
                  ),
                  // Big, always-present advance arrow — only tappable once
                  // solved. Lesson steps auto-advance instead, so no arrow.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('bs-next'),
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

class _PieceChip extends StatelessWidget {
  const _PieceChip({required this.element, required this.stage, this.faded = false});

  final SyllableElement element;
  final int stage;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.3 : 1,
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        // scaleDown keeps a wide letter-syllable ('the') on one line inside
        // the fixed chip instead of wrapping and overflowing it.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: TokenView(element, stage: stage, size: 52),
        ),
      ),
    );
  }
}

class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({
    super.key,
    required this.piece,
    required this.stage,
    required this.onTap,
  });

  final _Piece piece;
  final int stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = _PieceChip(element: piece.element, stage: stage);
    return Draggable<_Piece>(
      data: piece,
      feedback: Material(color: Colors.transparent, child: chip),
      childWhenDragging:
          _PieceChip(element: piece.element, stage: stage, faded: true),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.piece,
    required this.stage,
    required this.onAccept,
    required this.onTap,
  });

  final int index;
  final _Piece? piece;
  final int stage;
  final ValueChanged<_Piece> onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_Piece>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            key: Key('bs-slot-$index'),
            width: 72,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: candidate.isNotEmpty
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            child: piece == null
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TokenView(piece!.element, stage: stage, size: 52),
                  ),
          ),
        );
      },
    );
  }
}
