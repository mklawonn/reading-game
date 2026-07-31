import 'dart:async';
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
import '../common/guide_character.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Feed the Guide** (Stage 0–1): the hungry guide asks for things by name
/// ("Fern wants the hat!") and the child gives them by tapping the matching
/// picture card — or dragging it onto the guide. The same sound→symbol drill
/// as Listen & Pick, but relational and silly: the child is feeding a friend.
/// A round is [requestCount] requests, then the guide is full.
class FeedTheGuidePage extends StatefulWidget {
  const FeedTheGuidePage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.guide = const Guide('🦊', 'Fern'),
    this.requestCount = 3,
    this.optionCount = 4,
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

  /// The character doing the asking (and eating) — the lesson passes the
  /// level's guide so the same face fronts the whole level.
  final Guide guide;

  /// How many things the guide asks for before it is full (one round).
  final int requestCount;
  final int optionCount;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven target selection. When null, falls back to uniform random.
  final ItemSampler? sampler;

  /// Restricts the pool to these element ids (curriculum's introduced symbols).
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer this element as the first request's target.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong attempts.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<FeedTheGuidePage> createState() => _FeedTheGuidePageState();
}

class _FeedTheGuidePageState extends State<FeedTheGuidePage>
    with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  SyllableElement? _target;
  List<SyllableElement> _options = const [];
  int _requestsTotal = 0;
  int _fed = 0;
  bool _wrong = false;

  /// Between a correct feed and the next request's start: gives are ignored so
  /// a mashing child can't double-feed while the guide is still munching.
  bool _transitioning = false;

  /// The whole round is done — the guide is full.
  bool _full = false;
  int _score = 0;

  GuideMood _mood = GuideMood.idle;
  bool _munch = false;
  Timer? _reactTimer;

  /// Invalidates an in-flight "Yum → next request" chain if a new round starts.
  int _chainEpoch = 0;

  /// How long the 😋 munch overlay (and the mood) lingers after a give.
  static const Duration _reactDuration = Duration(milliseconds: 900);

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

  SyllableElement? _focusElement() {
    if (_target != null) return null; // focus applies to the first request only
    for (final e in _pool) {
      if (e.id == widget.focusId) return e;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    _chainEpoch++;
    _requestsTotal = min(widget.requestCount, _pool.length);
    _fed = 0;
    _full = false;
    _startRequest();
  }

  /// A uniform random pick that avoids asking for the same thing twice in a
  /// row (the fallback when no [ItemSampler] is injected).
  SyllableElement _randomTarget(String? exclude) {
    final candidates =
        _pool.where((e) => e.id != exclude).toList(growable: false);
    final from = candidates.isEmpty ? _pool : candidates;
    return from[_random.nextInt(from.length)];
  }

  void _startRequest() {
    final count = min(widget.optionCount, _pool.length);
    final target = _focusElement() ??
        widget.sampler?.pick<SyllableElement>(
          _pool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _target?.id,
        ) ??
        _randomTarget(_target?.id);
    final distractors = [..._pool]
      ..removeWhere((e) => e.id == target.id)
      ..shuffle(_random);
    // Never seat look-alike pictures together (dog vs pup, …).
    _options = fillVisuallyDistinct([target], distractors, count, (e) => e.id)
      ..shuffle(_random);
    _target = target;
    _wrong = false;
    _transitioning = false;
  }

  /// Spoken on load and at each request — the guide asks for the target by
  /// name, which IS the listening task ("Fern wants the hat!").
  void _speakInstruction() {
    final target = _target;
    if (target != null) {
      widget.audioService
          .speak('${widget.guide.name} wants the ${target.syllable}!');
    }
  }

  /// Briefly show a reaction (mood + optional 😋 munch), then settle to idle.
  void _react(GuideMood mood, {bool munch = false}) {
    _reactTimer?.cancel();
    setState(() {
      _mood = mood;
      _munch = munch;
    });
    _reactTimer = Timer(_reactDuration, () {
      if (!mounted) return;
      setState(() {
        _mood = GuideMood.idle;
        _munch = false;
      });
    });
  }

  /// The single "give" seam — reached by tapping a card OR dropping it on the
  /// guide, so both gestures behave identically.
  void _onGive(SyllableElement picked) {
    if (_full || _transitioning) return;
    final target = _target!;
    final correct = picked.id == target.id;
    widget.onEvent?.call(LearningEvent(
      itemId: target.id,
      skill: 'recognize',
      stage: target.introducedStage,
      correct: correct,
      game: 'feed_the_guide',
    ));
    if (!correct) {
      noteWrongAttempt();
      setState(() => _wrong = true);
      _react(GuideMood.sad);
      // Name what they touched — never binding the target's label to the
      // wrong picture.
      widget.audioService.speak('Oops! That is the ${picked.syllable}.');
      return;
    }

    final lastRequest = _fed + 1 >= _requestsTotal;
    setState(() {
      _fed += 1;
      _wrong = false;
    });
    _react(GuideMood.happy, munch: true);
    if (lastRequest) {
      // The guide is full: one utterance carries the munch, the thanks, and
      // the round's close — the lesson advance waits for it to finish.
      final speech = widget.audioService.speak(
          'Yum! ${target.syllable}! ${widget.guide.name} is full — thank you!');
      setState(() {
        _full = true;
        _score += 1;
      });
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      setState(() => _transitioning = true);
      // Let "Yum!" ring out before the next request is voiced (echo_read's
      // chain pattern) — with a timeout guard so wedged TTS can't stall play.
      final epoch = _chainEpoch;
      widget.audioService
          .speak('Yum! ${target.syllable}!')
          .timeout(const Duration(seconds: 3), onTimeout: () {})
          .then((_) {
        if (!mounted || epoch != _chainEpoch) return;
        setState(_startRequest);
        _speakInstruction();
      });
    }
  }

  void _next() {
    setState(_startRound);
    _speakInstruction();
  }

  @override
  void dispose() {
    _reactTimer?.cancel();
    super.dispose();
  }

  /// The option cards in up to two columns, sized to always fill (and fit)
  /// the space below the guide.
  Widget _optionsGrid() {
    final columns = _options.length <= 3 ? _options.length : 2;
    return Column(
      children: [
        for (var row = 0; row < _options.length; row += columns) ...[
          if (row > 0) const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                for (var i = row; i < row + columns; i++) ...[
                  if (i > row) const SizedBox(width: 16),
                  Expanded(
                    child: i < _options.length
                        ? _FoodCard(
                            key: Key('fg-option-${_options[i].id}'),
                            element: _options[i],
                            dimmed: (_transitioning || _full) &&
                                _options[i].id != _target!.id,
                            onGive: () => _onGive(_options[i]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Feed the Guide'),
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
            return const Center(child: Text('Not enough to play.'));
          }
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Text('Feed ${widget.guide.name}!',
                    style: Theme.of(context).textTheme.titleLarge),
                // The guide sits big at the top and doubles as the drop zone.
                DragTarget<SyllableElement>(
                  key: const Key('fg-guide'),
                  onAcceptWithDetails: (details) => _onGive(details.data),
                  builder: (context, candidates, rejected) {
                    // A fixed-size stage: the munch overlay and the hover
                    // scale can never reflow the board below.
                    return SizedBox(
                      width: 200,
                      height: 132,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedScale(
                            scale: candidates.isNotEmpty ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: GuideCharacter(
                              guide: widget.guide,
                              mood: _mood,
                              size: 96,
                            ),
                          ),
                          Positioned(
                            right: 24,
                            bottom: 4,
                            child: Opacity(
                              opacity: _munch ? 1 : 0,
                              child: const Text('😋',
                                  style: TextStyle(fontSize: 40)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('fg-hear'),
                      tooltip: 'Hear it again',
                      onPressed: _speakInstruction,
                      icon: const Icon(Icons.volume_up),
                    ),
                    const SizedBox(width: 8),
                    // One plate per request, filled as it's fed — the child
                    // sees how many bites are left.
                    Row(
                      key: const Key('fg-plates'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _requestsTotal; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Icon(
                              i < _fed
                                  ? Icons.circle
                                  : Icons.circle_outlined,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Fixed-height slot: feedback never shoves the cards around.
                FeedbackSlot(
                  child: _full
                      ? Text('🎉 All fed!',
                          key: const Key('fg-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — try again!',
                              key: const Key('fg-wrong'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                          : null,
                ),
                // A fixed grid (no scroll viewport): every card stays on
                // screen and grabbable — a scrollable would cull off-screen
                // cards and fight the drag-to-guide gesture.
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _optionsGrid(),
                  ),
                ),
                // Big, always-present advance arrow — only tappable once the
                // guide is full. Lesson steps auto-advance instead, no arrow.
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('fg-next'),
                      enabled: _full,
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

/// A big picture card the child can tap OR drag onto the guide — both routes
/// call [onGive] so the two gestures are interchangeable.
class _FoodCard extends StatelessWidget {
  const _FoodCard({
    super.key,
    required this.element,
    required this.dimmed,
    required this.onGive,
  });

  final SyllableElement element;
  final bool dimmed;
  final VoidCallback onGive;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onGive,
        // Scale down (never up) so a short card still shows the whole glyph.
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: GlyphView(element, size: 64),
          ),
        ),
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Draggable<SyllableElement>(
        data: element,
        maxSimultaneousDrags: dimmed ? 0 : 1,
        feedback: Material(
          color: Colors.transparent,
          child: GlyphView(element, size: 72),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: card,
      ),
    );
  }
}
