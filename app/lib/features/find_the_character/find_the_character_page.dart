import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';

/// **Find the Character** (Stage 1): a written word/command is shown (with
/// tap-to-hear support) and the child taps the matching picture among options —
/// gamifying the comprehension test from Gleitman & Rozin's Table 2.
class FindTheCharacterPage extends StatefulWidget {
  const FindTheCharacterPage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.optionCount = 3,
    this.random,
    this.sampler,
    this.allowedIds,
    this.embedded = false,
    this.onEvent,
  });

  final ContentService contentService;
  final AudioService audioService;
  final int optionCount;

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

  @override
  State<FindTheCharacterPage> createState() => _FindTheCharacterPageState();
}

class _FindTheCharacterPageState extends State<FindTheCharacterPage> {
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
    }
  }

  void _startRound() {
    final count = min(widget.optionCount, _pool.length);
    // Mastery steers the target; distractors are filled in around it.
    final target = widget.sampler?.pick(
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

  /// Spoken on load and on each new round — names the task aloud so a
  /// pre-reader always knows what to do without tapping anything.
  void _speakInstruction() {
    final target = _target;
    if (target != null) widget.audioService.speak('Find the ${target.syllable}!');
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
      game: 'find_the_character',
    ));
    if (correct) {
      setState(() {
        _solved = true;
        _wrong = false;
        _score += 1;
      });
      widget.audioService.speak(picked.syllable);
    } else {
      setState(() => _wrong = true);
      _speakTarget(); // gentle nudge: replay the word
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
        title: const Text('Find the Character'),
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
          final target = _target!;
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Find the picture for this word',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // The written word — the reading challenge — with audio support.
                // The leading box mirrors the IconButton so the word itself is
                // truly centered (not the word+icon pair).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    SyllableTile(
                      target.syllable,
                      key: const Key('fc-prompt'),
                      fontSize: 40,
                    ),
                    IconButton(
                      key: const Key('fc-hear'),
                      onPressed: _speakTarget,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Hear it',
                    ),
                  ],
                ),
                // Fixed-height slot: feedback never shoves the options around.
                FeedbackSlot(
                  child: _solved
                      ? Text('🎉 Yes!',
                          key: const Key('fc-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — listen again!',
                              key: const Key('fc-wrong'),
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
                          key: Key('fc-option-${element.id}'),
                          emoji: kPictographEmoji[element.id]!,
                          dimmed: _solved && element.id != target.id,
                          onTap: () => _onPick(element),
                        ),
                    ],
                  ),
                ),
                // Big, always-present advance arrow — only tappable once solved.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: NextArrowBar(
                    key: const Key('fc-next'),
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
