import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/token_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/phrase.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Echo Read** — guided sentence reading. A short phrase is shown in the
/// child's current-stage orthography ([stage]); the child taps its tokens
/// LEFT TO RIGHT, hearing each one, and when the last is tapped the whole
/// sentence is spoken fluently. Teaches reading direction and fluency.
///
/// There is no way to fail: tapping any token speaks it (the app-wide
/// tap-to-hear invariant), and only the expected leftmost-untapped token
/// advances the highlight — a confidence/pacing exercise, always flawless.
///
/// When no usable phrase exists yet (early levels), the game synthesizes a
/// "picture row" of picturable symbols to read left-to-right — mirroring the
/// Gleitman & Rozin pictograph-row reading exercise.
class EchoReadPage extends StatefulWidget {
  const EchoReadPage({
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

  /// Kept for contract uniformity with the other games; Echo Read has no
  /// per-item drill choice (a whole phrase/row is the unit), so it is unused.
  final ItemSampler? sampler;

  /// Restricts phrases (and synthesized rows) to these introduced element ids.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] once per completed round (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play one round, then auto-advance via [onRoundComplete]
  /// (no "next" arrow).
  final bool singleRound;

  /// Preferred element to lead a synthesized picture row with, when provided.
  final String? focusId;

  /// Reports round completion (always flawless — Echo Read cannot be failed).
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<EchoReadPage> createState() => _EchoReadPageState();
}

class _EchoReadPageState extends State<EchoReadPage>
    with SingleRoundFlow<EchoReadPage> {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _elementById = {};
  List<SyllableElement> _picturablePool = const [];
  List<Phrase> _phrases = const [];

  /// The round is just an ordered token row — from a phrase or synthesized.
  List<SyllableElement> _tokens = const [];
  Phrase? _phrase; // null when the row was synthesized
  int _readCount = 0;
  int _score = 0;
  String? _prevPhraseId;

  bool get _done => _tokens.isNotEmpty && _readCount == _tokens.length;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    _picturablePool = bank.elements
        .where(
            (e) => e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    final set = await widget.contentService.loadPhrases();
    // Keep phrases whose every token resolves and (if scoped) is introduced.
    _phrases = set.phrases
        .where((p) =>
            p.tokens.every(_elementById.containsKey) &&
            (widget.allowedIds == null ||
                p.tokens.every(widget.allowedIds!.contains)))
        .toList(growable: false);
    if (_phrases.isNotEmpty || _picturablePool.length >= 2) {
      setState(_startRound);
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  static const _instruction = 'Read with me! Tap each one.';
  void _speakInstruction() => widget.audioService.speak(_instruction);

  void _startRound() {
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
      _tokens = _synthesizeRow();
    }
    _readCount = 0;
    resetRoundFlaws();
  }

  /// Fallback for early levels with no usable phrase: an ordered "picture row"
  /// of 3–4 distinct picturable symbols (fewer only if the pool is smaller),
  /// led by the [EchoReadPage.focusId] element when one is provided.
  List<SyllableElement> _synthesizeRow() {
    final pool = [..._picturablePool]..shuffle(_random);
    if (widget.focusId != null) {
      final at = pool.indexWhere((e) => e.id == widget.focusId);
      if (at > 0) pool.insert(0, pool.removeAt(at));
    }
    final count = min(pool.length, 3 + _random.nextInt(2));
    return pool.take(count).toList(growable: false);
  }

  Future<void> _speak(SyllableElement e) =>
      widget.audioService.speak(e.syllable);

  void _onTapToken(int index) {
    // Tap-to-hear is a hard app invariant: every token always speaks.
    final speech = _speak(_tokens[index]);
    // Only the expected (leftmost untapped) token advances — no penalty else.
    if (_done || index != _readCount) return;
    setState(() {
      _readCount += 1;
      if (_done) _score += 1;
    });
    if (_done) _completeRound(afterLastWord: speech);
  }

  void _completeRound({required Future<void> afterLastWord}) {
    widget.onEvent?.call(LearningEvent(
      itemId: _phrase?.answer ?? _tokens.first.id,
      skill: 'read',
      stage: widget.stage,
      correct: true,
      game: 'echo_read',
    ));
    // Let the last word ring out ALONE first — speaking over it would rob the
    // child of the token they just read — then echo the whole sentence
    // fluently and praise the finish. The lesson advance waits for the echo.
    final echoed = afterLastWord
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .then((_) {
      if (!mounted) return Future<void>.value();
      return widget.audioService
          .speak('${_tokens.map((e) => e.syllable).join(' ')}. You read it!');
    });
    // Flawless is always true: noteWrongAttempt is never called here.
    scheduleRoundComplete(widget.onRoundComplete, afterSpeech: echoed);
  }

  void _next() {
    setState(_startRound);
    _speakInstruction();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Echo Read'),
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
            return const Center(child: Text('Nothing to read yet.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Read with me!',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 24),
                  // The token row (full width ⇒ centering is unconditional).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < _tokens.length; i++) _tokenTile(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fixed-height slot keeps the row steady when it appears.
                  FeedbackSlot(
                    child: _done
                        ? Text('🎉 You read it!',
                            key: const Key('er-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : null,
                  ),
                  const Spacer(),
                  // Big, always-present advance arrow — tappable once read.
                  // A lesson step (singleRound) auto-advances instead.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('er-next'),
                      enabled: _done,
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

  /// One tappable token. The next expected token carries a primary-color
  /// highlight border; already-read tokens get a filled look. Border width is
  /// constant so tokens never move as the highlight advances.
  Widget _tokenTile(int index) {
    final scheme = Theme.of(context).colorScheme;
    final read = index < _readCount;
    final expected = !_done && index == _readCount;
    return GestureDetector(
      onTap: () => _onTapToken(index),
      child: Container(
        key: Key('er-token-$index'),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              read ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: expected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: TokenView(_tokens[index], stage: widget.stage, size: 64),
      ),
    );
  }
}
