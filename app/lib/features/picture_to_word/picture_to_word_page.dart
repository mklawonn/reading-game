import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/praise.dart';
import '../common/single_round.dart';

/// **Picture to Word**: the reverse of Find-the-Character — the child sees a
/// big picture, hears its name, and taps the matching *written* word among
/// options. This trains the sound→print mapping: given a meaning and its
/// spoken form, find the print that says it.
class PictureToWordPage extends StatefulWidget {
  const PictureToWordPage({
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

  /// Restricts the pool to these element ids (the curriculum's introduced
  /// symbols). Null = no restriction.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Play as one lesson step: the "next" arrow is omitted and completion is
  /// reported through [onRoundComplete] instead (see [SingleRoundFlow]).
  final bool singleRound;

  /// Element id the first round should target (the lesson's focus item). Falls
  /// back to normal selection when null or not in the pool.
  final String? focusId;

  /// Fired after the solve celebration with whether the round was flawless
  /// (no wrong picks). Wired by the lesson host alongside [singleRound].
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<PictureToWordPage> createState() => _PictureToWordPageState();
}

class _PictureToWordPageState extends State<PictureToWordPage>
    with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  List<SyllableElement> _pool = const [];
  SyllableElement? _target;
  List<SyllableElement> _options = const [];
  bool _solved = false;
  bool _wrong = false;
  bool _firstRound = true;
  int _score = 0;

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

  void _startRound() {
    final count = min(widget.optionCount, _pool.length);
    // The lesson's focus item leads the first round; after that, mastery
    // steers the target and distractors are filled in around it.
    SyllableElement? focus;
    if (_firstRound && widget.focusId != null) {
      for (final e in _pool) {
        if (e.id == widget.focusId) {
          focus = e;
          break;
        }
      }
    }
    final target = focus ??
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
    _firstRound = false;
    _solved = false;
    _wrong = false;
    resetRoundFlaws();
  }

  void _speakTarget() {
    final target = _target;
    if (target != null) widget.audioService.speak(target.syllable);
  }

  /// Spoken on load and on each new round. Naming the target aloud is correct
  /// here — the reading work is finding the *print* for the heard sound.
  void _speakInstruction() {
    final target = _target;
    if (target != null) {
      widget.audioService.speak('Which word says ${target.syllable}?');
    }
  }

  void _onPick(SyllableElement picked) {
    if (_solved) return;
    final target = _target!;
    final correct = picked.id == target.id;
    widget.onEvent?.call(LearningEvent(
      itemId: target.id,
      skill: 'read',
      stage: target.introducedStage,
      correct: correct,
      game: 'picture_to_word',
    ));
    if (correct) {
      setState(() {
        _solved = true;
        _wrong = false;
        _score += 1;
      });
      final speech = widget.audioService
          .speak('${praiseLine(_random)} ${picked.syllable}!');
      scheduleRoundComplete(widget.onRoundComplete, afterSpeech: speech);
    } else {
      setState(() => _wrong = true);
      noteWrongAttempt();
      // Distinctly a miss — and it still teaches what the picked print says.
      widget.audioService
          .speak('Oops! That word says ${picked.syllable}.');
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
        title: const Text('Picture to Word'),
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
            return const Center(child: Text('Not enough words to play.'));
          }
          final target = _target!;
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text('Find the word for this picture',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                // The big picture — tap it to re-hear its name. The leading box
                // mirrors the IconButton so the picture itself is truly
                // centered (not the picture+icon pair).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    Material(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        key: const Key('pw-picture'),
                        borderRadius: BorderRadius.circular(24),
                        onTap: _speakTarget,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: GlyphView(target, size: 110),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('pw-hear'),
                      onPressed: _speakInstruction,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Hear it',
                    ),
                  ],
                ),
                // Fixed-height slot: feedback never shoves the options around.
                FeedbackSlot(
                  child: _solved
                      ? Text('🎉 Yes!',
                          key: const Key('pw-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Look at the letters again!',
                              key: const Key('pw-wrong'),
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
                        _WordCard(
                          key: Key('pw-option-${element.id}'),
                          syllable: element.syllable,
                          dimmed: _solved && element.id != target.id,
                          onTap: () => _onPick(element),
                        ),
                    ],
                  ),
                ),
                // Big, always-present advance arrow — only tappable once
                // solved. A lesson step advances itself instead.
                if (!widget.singleRound)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: NextArrowBar(
                      key: const Key('pw-next'),
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

class _WordCard extends StatelessWidget {
  const _WordCard({
    super.key,
    required this.syllable,
    required this.dimmed,
    required this.onTap,
  });

  final String syllable;
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
            child: SyllableTile(syllable, fontSize: 30),
          ),
        ),
      ),
    );
  }
}
