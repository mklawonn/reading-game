import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/praise.dart';
import '../common/single_round.dart';

/// **Listen & Pick** (Stage 0–1): the child hears a syllable and taps the
/// matching picture, building the sound→symbol link purely by ear.
class ListenAndPickPage extends StatefulWidget {
  const ListenAndPickPage({
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

  /// Prefer this element as the first round's target.
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong attempts.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<ListenAndPickPage> createState() => _ListenAndPickPageState();
}

class _ListenAndPickPageState extends State<ListenAndPickPage>
    with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  SyllableElement? _target;
  List<SyllableElement> _options = const [];
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _pool = bank.elements
        .where((e) =>
            kPictographEmoji.containsKey(e.id) &&
            (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    if (_pool.length >= 2) {
      _startRound();
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  SyllableElement? _focusElement() {
    if (_target != null) return null; // focus applies to the first round only
    for (final e in _pool) {
      if (e.id == widget.focusId) return e;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    final count = min(widget.optionCount, _pool.length);
    final target = _focusElement() ??
        widget.sampler?.pick<SyllableElement>(
          _pool,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _target?.id,
        ) ??
        _pool[_random.nextInt(_pool.length)];
    final distractors = [..._pool]
      ..removeWhere((e) => e.id == target.id)
      ..shuffle(_random);
    _options = [target, ...distractors.take(count - 1)]..shuffle(_random);
    _target = target;
    _solved = false;
    _wrong = false;
  }

  void _speakTarget() {
    final target = _target;
    if (target != null) widget.audioService.speak(target.syllable);
  }

  /// Spoken on load and on each new round — names the task aloud. The child
  /// hears the target word framed as an instruction ("Tap the cat!").
  void _speakInstruction() {
    final target = _target;
    if (target != null) widget.audioService.speak('Tap the ${target.syllable}!');
  }

  void _onPick(SyllableElement picked) {
    if (_solved) return;
    final target = _target!;
    final correct = picked.id == target.id;
    widget.onEvent?.call(LearningEvent(
      itemId: target.id,
      skill: 'recognize',
      stage: target.introducedStage,
      correct: correct,
      game: 'listen_and_pick',
    ));
    if (correct) {
      setState(() {
        _solved = true;
        _wrong = false;
        _score += 1;
      });
      // Right answers must SOUND right: praise + the word, one utterance —
      // and the lesson waits for it to finish before moving on.
      final speech = widget.audioService
          .speak('${praiseLine(_random)} ${picked.syllable}!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      noteWrongAttempt();
      setState(() => _wrong = true);
      // A distinct gentle miss: name what they touched (never binding the
      // target's label to the wrong picture), then replay the target.
      widget.audioService.speak(
          'Oops! That is the ${picked.syllable}. Listen: ${target.syllable}!');
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
        title: const Text('Listen & Pick'),
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
            return const Center(child: Text('Not enough pictographs to play.'));
          }
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Tap what you hear',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('lp-replay'),
                  onPressed: _speakTarget,
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Hear it again'),
                ),
                const SizedBox(height: 8),
                // Fixed-height slot: feedback never shoves the options around.
                FeedbackSlot(
                  child: _solved
                      ? Text('🎉 Yes!',
                          key: const Key('lp-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — listen again!',
                              key: const Key('lp-wrong'),
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                          : null,
                ),
                Expanded(
                  child: GridView.count(
                    padding: const EdgeInsets.all(16),
                    crossAxisCount: _options.length <= 3 ? _options.length : 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      for (final element in _options)
                        _OptionCard(
                          key: Key('lp-option-${element.id}'),
                          emoji: kPictographEmoji[element.id]!,
                          dimmed: _solved && element.id != _target!.id,
                          onTap: () => _onPick(element),
                        ),
                    ],
                  ),
                ),
                // Big, always-present advance arrow — only tappable once
                // solved. Lesson steps auto-advance instead, so no arrow.
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('lp-next'),
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

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.emoji,
    required this.dimmed,
    required this.onTap,
  });

  final String emoji;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 64)),
          ),
        ),
      ),
    );
  }
}
