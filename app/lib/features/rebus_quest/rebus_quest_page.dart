import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../content/token_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/praise.dart';
import '../common/single_round.dart';

/// Things something can hide in — the scene's "furniture".
const Set<String> _containers = {
  'house', 'box', 'bed', 'pot', 'hat', 'can', 'tree', 'net',
};

/// **Rebus Quest**: a pictographic sentence is the *instruction* for a scene —
/// "[see] [the] [cat] [in] [the] [house]" — and the child must read it to act:
/// several hiders peek out of several containers, and only the sentence says
/// which pair is wanted. This is Gleitman & Rozin's pictographic-command
/// comprehension test grown into a game; the narrator deliberately never
/// reads the sentence (that would hand over the answer) — every token still
/// speaks when tapped.
class RebusQuestPage extends StatefulWidget {
  const RebusQuestPage({
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

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven choice of which hider to ask about. Null → uniform random.
  final ItemSampler? sampler;

  /// Restricts the pool to these element ids (curriculum's introduced symbols).
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a lesson.
  final bool embedded;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer this element (as hider or container) in the first round.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong attempts.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<RebusQuestPage> createState() => RebusQuestPageState();
}

class RebusQuestPageState extends State<RebusQuestPage> with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _byId = {};
  List<SyllableElement> _containerPool = const [];
  List<SyllableElement> _hiderPool = const [];
  List<SyllableElement> _sentenceGlue = const []; // see, the, in

  List<(SyllableElement hider, SyllableElement container)> _spots = const [];
  int _targetSpot = 0;
  String? _prevHiderId;
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  /// Element id of the hider at each spot, in order — lets tests locate the
  /// target without depending on layout.
  @visibleForTesting
  List<String> get spotHiderIds => [for (final s in _spots) s.$1.id];

  @visibleForTesting
  int get targetSpot => _targetSpot;

  /// Container element id at spot [index] (spot keys are per-container).
  @visibleForTesting
  String containerIdAt(int index) => _spots[index].$2.id;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    for (final e in bank.elements) {
      _byId[e.id] = e;
    }
    final allowed = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    _containerPool = allowed
        .where((e) => _containers.contains(e.id))
        .toList(growable: false);
    _hiderPool = allowed
        .where((e) => !_containers.contains(e.id))
        .toList(growable: false);
    final glue = ['see', 'the', 'in'].map((id) => _byId[id]).toList();
    if (_containerPool.length >= 2 &&
        _hiderPool.length >= 2 &&
        !glue.contains(null)) {
      _sentenceGlue = glue.cast<SyllableElement>().toList(growable: false);
      _startRound();
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  /// Deliberately generic — the sentence is the reading challenge.
  void _speakInstruction() =>
      widget.audioService.speak('Read it! Who is hiding where?');

  void _startRound() {
    resetRoundFlaws();
    final n = min(3, min(_containerPool.length, _hiderPool.length));

    // Focus (a just-taught symbol) joins the scene wherever it fits.
    SyllableElement? focusHider;
    SyllableElement? focusContainer;
    if (widget.focusId != null && _spots.isEmpty) {
      for (final e in _hiderPool) {
        if (e.id == widget.focusId) focusHider = e;
      }
      for (final e in _containerPool) {
        if (e.id == widget.focusId) focusContainer = e;
      }
    }

    // The asked-about hider: mastery-steered; the rest fill in around it.
    final targetHider = focusHider ??
        widget.sampler?.pick<SyllableElement>(
          _hiderPool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _prevHiderId,
        ) ??
        _hiderPool[_random.nextInt(_hiderPool.length)];
    _prevHiderId = targetHider.id;

    final hiders = fillVisuallyDistinct(
      [targetHider],
      [..._hiderPool]..removeWhere((e) => e.id == targetHider.id)
        ..shuffle(_random),
      n,
      (e) => e.id,
    );
    final seedContainer = focusContainer ??
        _containerPool[_random.nextInt(_containerPool.length)];
    final containers = fillVisuallyDistinct(
      [seedContainer],
      [..._containerPool]
        ..removeWhere((e) => e.id == seedContainer.id)
        ..shuffle(_random),
      n,
      (e) => e.id,
    );

    _spots = [
      for (var i = 0; i < hiders.length; i++) (hiders[i], containers[i]),
    ]..shuffle(_random);
    _targetSpot = _spots.indexWhere((s) => s.$1.id == targetHider.id);
    _solved = false;
    _wrong = false;
  }

  List<SyllableElement> get _sentence {
    final (hider, container) = _spots[_targetSpot];
    final see = _sentenceGlue[0], the = _sentenceGlue[1], inn = _sentenceGlue[2];
    return [see, the, hider, inn, the, container];
  }

  void _onTapSpot(int index) {
    if (_solved) return;
    final (hider, container) = _spots[index];
    final target = _spots[_targetSpot];
    final correct = index == _targetSpot;
    widget.onEvent?.call(LearningEvent(
      itemId: target.$1.id,
      skill: 'read',
      stage: target.$1.introducedStage,
      correct: correct,
      game: 'rebus_quest',
    ));
    if (correct) {
      setState(() {
        _solved = true;
        _wrong = false;
        _score += 1;
      });
      // The full sentence is the reward — heard only after it was read.
      final speech = widget.audioService.speak(
          '${praiseLine(_random)} The ${hider.syllable} is in the '
          '${container.syllable}!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      noteWrongAttempt();
      setState(() => _wrong = true);
      widget.audioService.speak(
          'Oops! That is the ${hider.syllable} in the ${container.syllable}.');
    }
  }

  void _next() {
    setState(_startRound);
    _speakInstruction();
  }

  String _emoji(SyllableElement e) => kPictographEmoji[e.id] ?? e.syllable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Rebus Quest'),
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
          if (_spots.isEmpty) {
            return const Center(child: Text('Not enough to play yet.'));
          }
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text('Read it, then find them!',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                // The pictographic command — every token speaks on tap.
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _sentence.length; i++)
                        TokenView(
                          _sentence[i],
                          key: Key('rq-token-$i'),
                          stage: 1,
                          size: 46,
                          onTap: () => widget.audioService
                              .speak(_sentence[i].syllable),
                        ),
                    ],
                  ),
                ),
                FeedbackSlot(
                  child: _solved
                      ? Text('🎉 You found them!',
                          key: const Key('rq-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Read the picture words again!',
                              key: const Key('rq-wrong'),
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error))
                          : null,
                ),
                Expanded(
                  child: Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 22,
                      runSpacing: 22,
                      children: [
                        for (var i = 0; i < _spots.length; i++)
                          _HidingSpot(
                            key: Key('rq-spot-${_spots[i].$2.id}'),
                            hiderEmoji: _emoji(_spots[i].$1),
                            containerEmoji: _emoji(_spots[i].$2),
                            revealed: _solved && i == _targetSpot,
                            dimmed: _solved && i != _targetSpot,
                            onTap: () => _onTapSpot(i),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('rq-next'),
                      enabled: _solved,
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

/// One container with its hider peeking out from behind the top edge; on the
/// solve the hider springs the rest of the way out.
class _HidingSpot extends StatelessWidget {
  const _HidingSpot({
    super.key,
    required this.hiderEmoji,
    required this.containerEmoji,
    required this.revealed,
    required this.dimmed,
    required this.onTap,
  });

  final String hiderEmoji;
  final String containerEmoji;
  final bool revealed;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: SizedBox(
          width: 130,
          height: 165,
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // The hider, peeking — springs up when found.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                bottom: revealed ? 96 : 62,
                child: Text(hiderEmoji,
                    style: TextStyle(fontSize: revealed ? 62 : 46)),
              ),
              // The container in front.
              Positioned(
                bottom: 0,
                child:
                    Text(containerEmoji, style: const TextStyle(fontSize: 96)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
