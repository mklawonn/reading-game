import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';

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
      _speakTarget();
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
  }

  void _speakTarget() {
    final target = _target;
    if (target != null) widget.audioService.speak(target.syllable);
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
        _score += 1;
      });
      widget.audioService.speak(picked.syllable);
    } else {
      setState(() {}); // surface the "try again" hint
    }
  }

  void _next() {
    setState(_startRound);
    _speakTarget();
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                if (_solved)
                  Padding(
                    key: const Key('fc-feedback'),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text('🎉 Yes!',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('fc-next'),
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
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
