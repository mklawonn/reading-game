import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Blend Magic** (Stage 2): the recognition side of blending. Two syllable
/// cards slide together on screen while being sounded out (`o` … `pen` …
/// `open!`), then the child picks which written word the pieces made from a
/// few options. Where Build-a-Word constructs, Blend Magic recognizes — it
/// teaches that the pieces' sounds compose the word.
class BlendRevealPage extends StatefulWidget {
  const BlendRevealPage({
    super.key,
    required this.contentService,
    required this.audioService,
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
  final int optionCount;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven target selection. When null, falls back to uniform random
  /// (keeps widget tests deterministic via [random]).
  final ItemSampler? sampler;

  /// Restricts blendable words to those whose syllables are all introduced.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer a word matching this id (or containing this syllable) as the first
  /// round's target (e.g. a just-introduced symbol or a missed word).
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong attempts.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<BlendRevealPage> createState() => _BlendRevealPageState();
}

class _BlendRevealPageState extends State<BlendRevealPage>
    with SingleTickerProviderStateMixin, SingleRoundFlow {
  /// Extra distance (px) between the two cards before they slide together.
  static const double _startGap = 80;

  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  /// Drives the two cards from apart to adjacent — runs once per reveal.
  late final AnimationController _slide;

  /// Audio sequencing for the reveal (syllable … syllable … word).
  final List<Timer> _timers = [];

  final Map<String, SyllableElement> _elementById = {};
  List<Word> _blendable = const [];

  late Word _word;
  String? _prevWordId;
  List<Word> _options = const [];
  bool _revealed = false;
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener(_onSlideStatus);
  }

  @override
  void dispose() {
    _cancelTimers();
    _slide.dispose();
    super.dispose();
  }

  void _onSlideStatus(AnimationStatus status) {
    // The pieces have met — now the options may be picked.
    if (status == AnimationStatus.completed && !_revealed && mounted) {
      setState(() => _revealed = true);
    }
  }

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    // Blendable = taught two-piece blends whose syllables are all known.
    _blendable = bank.words
        .where((w) =>
            !w.isTestBlend &&
            w.segmentation.length == 2 &&
            w.segmentation.every(_elementById.containsKey) &&
            (widget.allowedIds == null ||
                w.segmentation.every(widget.allowedIds!.contains)))
        .toList(growable: false);
    if (_blendable.length >= 2) {
      _startRound();
      _beginReveal();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  // A blend's stage = the latest stage among its component syllables.
  int _wordStage(Word w) => w.segmentation
      .map((id) => _elementById[id]?.introducedStage ?? 2)
      .fold(1, (a, b) => a > b ? a : b);

  /// The lesson's focus (a just-introduced syllable or a missed word) wins the
  /// first round: match by word id, or by a syllable the word contains.
  Word? _focusWord() {
    if (_prevWordId != null) return null; // focus applies to the first round only
    final focusId = widget.focusId;
    if (focusId == null) return null;
    for (final w in _blendable) {
      if (w.id == focusId || w.segmentation.contains(focusId)) return w;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    final count = min(widget.optionCount, _blendable.length);
    // The lesson's focus wins; else mastery steers the target; distractors are
    // filled in around it.
    final word = _focusWord() ??
        widget.sampler?.pick<Word>(
          _blendable,
          id: (w) => w.id,
          stage: _wordStage,
          exclude: _prevWordId,
        ) ??
        _blendable[_random.nextInt(_blendable.length)];
    final others = [..._blendable]
      ..removeWhere((w) => w.id == word.id)
      ..shuffle(_random);
    _options = [word, ...others.take(count - 1)]..shuffle(_random);
    _word = word;
    _prevWordId = word.id;
    _revealed = false;
    _solved = false;
    _wrong = false;
  }

  /// Spoken on load and on each new round — names the task, then the pieces
  /// are sounded out as they slide.
  void _beginReveal() {
    widget.audioService.speak('Watch the pieces make a word!');
    _playReveal();
  }

  /// Runs (or replays) the reveal: the cards slide together while the pieces
  /// are sounded out, and the whole word is spoken as they meet.
  void _playReveal() {
    _cancelTimers();
    _slide.forward(from: 0);
    final first = _elementById[_word.segmentation[0]]!;
    final second = _elementById[_word.segmentation[1]]!;
    widget.audioService.speak(first.syllable);
    _timers.add(Timer(const Duration(milliseconds: 700), () {
      widget.audioService.speak(second.syllable);
    }));
    _timers.add(Timer(const Duration(milliseconds: 1500), () {
      widget.audioService.speak(_word.text);
    }));
  }

  void _cancelTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  void _onPick(Word picked) {
    if (!_revealed || _solved) return; // no picking until the pieces have met
    final correct = picked.id == _word.id;
    widget.onEvent?.call(LearningEvent(
      itemId: _word.id,
      skill: 'blend',
      stage: 2,
      correct: correct,
      game: 'blend_reveal',
    ));
    if (correct) {
      setState(() {
        _solved = true;
        _wrong = false;
        _score += 1;
      });
      final speech =
          widget.audioService.speak('You got it! ${_word.text}!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      noteWrongAttempt();
      setState(() => _wrong = true);
      // The child hears what the picked word actually says.
      widget.audioService.speak('Oops! That says ${picked.text}.');
    }
  }

  void _next() {
    setState(_startRound);
    _beginReveal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: const Text('Blend Magic'),
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
          if (_blendable.length < 2) {
            return const Center(child: Text('No words to blend yet.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Watch the pieces make a word',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  // The two syllable cards, positioned symmetrically around the
                  // center; they start apart and slide until adjacent.
                  SizedBox(
                    height: 104,
                    child: AnimatedBuilder(
                      animation: _slide,
                      builder: (context, _) {
                        final t = Curves.easeInOut.transform(_slide.value);
                        // Half the distance between the card centers: 50 when
                        // adjacent (96px card + 4px gap), plus the shrinking
                        // start gap.
                        final apart = 50 + _startGap * (1 - t) / 2;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            for (var i = 0; i < 2; i++)
                              Transform.translate(
                                offset: Offset((i == 0 ? -1 : 1) * apart, 0),
                                child: _pieceCard(context, i),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Replay the whole reveal — slide and sound-out together.
                  IconButton(
                    key: const Key('br-hear'),
                    onPressed: _playReveal,
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Hear it again',
                  ),
                  // Fixed-height slot: feedback never shoves the options around.
                  FeedbackSlot(
                    child: _solved
                        ? Text('🎉 ${_word.text}!',
                            key: const Key('br-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : _wrong
                            ? Text('Not that one — listen again!',
                                key: const Key('br-wrong'),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))
                            : null,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < _options.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          Expanded(
                            child: _OptionCard(
                              key: Key('br-option-${_options[i].id}'),
                              syllables: [
                                for (final id in _options[i].segmentation)
                                  _elementById[id]!.syllable,
                              ],
                              opacity: !_revealed
                                  ? 0.4
                                  : (_solved && _options[i].id != _word.id)
                                      ? 0.35
                                      : 1.0,
                              onTap: () => _onPick(_options[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Big, always-present advance arrow — only tappable once
                  // solved. Lesson steps auto-advance instead, so no arrow.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('br-next'),
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

  Widget _pieceCard(BuildContext context, int index) {
    return Container(
      key: Key('br-piece-$index'),
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SyllableTile(
        _elementById[_word.segmentation[index]]!.syllable,
        fontSize: 28,
      ),
    );
  }
}

/// One written-word option, rendered as its syllable **chunks** side by side —
/// the syllable, not the letter, stays the reading unit.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.syllables,
    required this.opacity,
    required this.onTap,
  });

  final List<String> syllables;
  final double opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < syllables.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  SyllableTile(syllables[i], fontSize: 22),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
