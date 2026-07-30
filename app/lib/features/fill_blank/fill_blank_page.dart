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
import '../common/praise.dart';
import '../common/single_round.dart';

/// **Fill-in-the-Blank** (Stages 1–4): a short phrase is shown with one token
/// missing; the child drags the right symbol into the slot. Every token is a
/// Content Bank element, so the phrase renders in the child's current-stage
/// orthography ([stage]) — the same phrase repeats across stages (pictures →
/// letters). Tap any token (or candidate) to hear it.
class FillBlankPage extends StatefulWidget {
  const FillBlankPage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.stage = 1,
    this.optionCount = 3,
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
  final int optionCount;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven choice of which blank to drill. Null → uniform random.
  final ItemSampler? sampler;

  /// Restricts phrases (and distractors) to these introduced element ids.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each drop (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer a phrase whose blank is this element for the first round.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong drops.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<FillBlankPage> createState() => _FillBlankPageState();
}

class _FillBlankPageState extends State<FillBlankPage> with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _elementById = {};
  List<SyllableElement> _picturablePool = const [];
  List<SyllableElement> _answerPool = const []; // distinct answer elements
  List<Phrase> _phrases = const [];

  Phrase? _phrase;
  List<SyllableElement> _options = const [];
  SyllableElement? _placed;
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;
  String? _prevPhraseId;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    _picturablePool = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    final set = await widget.contentService.loadPhrases();
    // Keep phrases whose every token resolves and (if scoped) is introduced.
    _phrases = set.phrases
        .where((p) =>
            p.tokens.every(_elementById.containsKey) &&
            (widget.allowedIds == null ||
                p.tokens.every(widget.allowedIds!.contains)))
        .toList(growable: false);
    final answerIds = {for (final p in _phrases) p.answer};
    _answerPool = [
      for (final id in answerIds)
        if (_elementById[id] != null) _elementById[id]!,
    ];
    if (_phrases.isNotEmpty) {
      setState(_startRound);
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  static const _instruction = 'Finish the sentence.';
  void _speakInstruction() => widget.audioService.speak(_instruction);

  SyllableElement? _focusElement() {
    if (_phrase != null) return null; // first round only
    for (final e in _answerPool) {
      if (e.id == widget.focusId) return e;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    // The lesson's focus wins; else mastery picks which answer (blank) to
    // drill; then a phrase that uses it.
    final answer = _focusElement() ??
        widget.sampler?.pick<SyllableElement>(
          _answerPool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
        ) ??
        _answerPool[_random.nextInt(_answerPool.length)];
    final fresh = _phrases
        .where((p) => p.answer == answer.id && p.id != _prevPhraseId)
        .toList();
    final pool = fresh.isNotEmpty
        ? fresh
        : _phrases.where((p) => p.answer == answer.id).toList();
    final phrase = pool[_random.nextInt(pool.length)];
    _prevPhraseId = phrase.id;
    _phrase = phrase;

    // Options = the answer + distractors (curated if given, else picturables).
    final distractors = phrase.distractors
        .map((id) => _elementById[id])
        .whereType<SyllableElement>()
        .toList();
    if (distractors.length < widget.optionCount - 1) {
      final extra = [..._picturablePool]
        ..removeWhere(
            (e) => e.id == answer.id || distractors.any((d) => d.id == e.id))
        ..shuffle(_random);
      distractors
          .addAll(extra.take(widget.optionCount - 1 - distractors.length));
    }
    _options = [answer, ...distractors.take(widget.optionCount - 1)]
      ..shuffle(_random);
    _placed = null;
    _solved = false;
    _wrong = false;
  }

  void _speak(SyllableElement e) => widget.audioService.speak(e.syllable);

  void _onDrop(SyllableElement element) {
    if (_solved) return;
    final answerId = _phrase!.answer;
    final correct = element.id == answerId;
    widget.onEvent?.call(LearningEvent(
      itemId: answerId,
      skill: 'read',
      stage: _elementById[answerId]?.introducedStage ?? widget.stage,
      correct: correct,
      game: 'fill_blank',
    ));
    setState(() {
      if (correct) {
        _placed = element;
        _solved = true;
        _wrong = false;
        _score += 1;
      } else {
        noteWrongAttempt();
        _wrong = true;
      }
    });
    if (correct) {
      final speech = widget.audioService
          .speak('${praiseLine(_random)} ${element.syllable}!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      widget.audioService
          .speak('Oops! ${element.syllable} does not fit. Try again!');
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
        title: const Text('Fill the Blank'),
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
          final phrase = _phrase;
          if (phrase == null) {
            return const Center(child: Text('No phrases available.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Finish the sentence',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 24),
                  // The phrase, with the blank rendered as a drop slot
                  // (full width ⇒ centering is unconditional).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < phrase.tokens.length; i++)
                          if (i == phrase.blank)
                            _BlankSlot(
                              filled: _placed,
                              stage: widget.stage,
                              onAccept: _onDrop,
                            )
                          else
                            TokenView(
                              _elementById[phrase.tokens[i]]!,
                              stage: widget.stage,
                              onTap: () =>
                                  _speak(_elementById[phrase.tokens[i]]!),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fixed-height slot keeps the board steady when it appears.
                  FeedbackSlot(
                    child: _solved
                        ? Text('🎉 Yes!',
                            key: const Key('fb-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : _wrong
                            ? Text('Not quite — try again',
                                key: const Key('fb-wrong'),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))
                            : null,
                  ),
                  const Spacer(),
                  // Draggable candidate symbols.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final e in _options)
                          if (_solved && e.id == _placed?.id)
                            _CandidateChip(
                                element: e, stage: widget.stage, faded: true)
                          else
                            Draggable<SyllableElement>(
                              key: Key('fb-option-${e.id}'),
                              data: e,
                              feedback: Material(
                                  color: Colors.transparent,
                                  child: _CandidateChip(
                                      element: e, stage: widget.stage)),
                              childWhenDragging: _CandidateChip(
                                  element: e, stage: widget.stage, faded: true),
                              child: GestureDetector(
                                onTap: () => _speak(e),
                                child: _CandidateChip(
                                    element: e, stage: widget.stage),
                              ),
                            ),
                      ],
                    ),
                  ),
                  // Big, always-present advance arrow — only tappable once
                  // solved. Lesson steps auto-advance instead, so no arrow.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('fb-next'),
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

class _BlankSlot extends StatelessWidget {
  const _BlankSlot({
    required this.filled,
    required this.stage,
    required this.onAccept,
  });

  final SyllableElement? filled;
  final int stage;
  final ValueChanged<SyllableElement> onAccept;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<SyllableElement>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final highlight = candidate.isNotEmpty;
        return Container(
          key: const Key('fb-slot'),
          width: 76,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled != null || highlight
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled != null ? scheme.primary : scheme.outline,
              width: 2,
            ),
          ),
          child:
              filled != null ? TokenView(filled!, stage: stage, size: 40) : null,
        );
      },
    );
  }
}

class _CandidateChip extends StatelessWidget {
  const _CandidateChip({
    required this.element,
    required this.stage,
    this.faded = false,
  });

  final SyllableElement element;
  final int stage;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.3 : 1,
      child: Container(
        width: 84,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: TokenView(element, stage: stage, size: 52),
      ),
    );
  }
}
