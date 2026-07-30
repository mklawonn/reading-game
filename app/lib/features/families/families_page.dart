import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/phoneme.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/praise.dart';
import '../common/single_round.dart';

/// **Sound Families** (Stage 3): minimal-pair contrast. Each round shows a target
/// word and asks for the one option that belongs to its family —
///  * **rhyme** mode: same rime (cat → hat), or
///  * **onset** mode: same first sound (key → can).
///
/// Onset mode is how we teach **stops**: a stop can't be voiced alone, so the
/// child learns /k/ by hearing key·can·cat share a beginning — never a bare /k/.
/// The "hear the sound" button uses [PhonemeSpeech], which anchors stops in their
/// keyword and stretches continuants.
class FamiliesPage extends StatefulWidget {
  const FamiliesPage({
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
  final Random? random;
  final ItemSampler? sampler;

  /// Restricts the pool to these element ids (curriculum's introduced symbols).
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play exactly one round, then auto-advance via
  /// [onRoundComplete] (no "next" tap). See [SingleRoundFlow].
  final bool singleRound;

  /// Prefer this element as the first round's target (if it's playable).
  final String? focusId;

  /// Called when the single round is done; `flawless` = no wrong attempts.
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<FamiliesPage> createState() => _FamiliesPageState();
}

class _FamiliesPageState extends State<FamiliesPage> with SingleRoundFlow {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _byId = {};
  final Map<String, List<SyllableElement>> _rhyme = {};
  final Map<String, List<SyllableElement>> _onset = {};
  List<SyllableElement> _pool = const [];
  List<SyllableElement> _playable = const [];
  PhonemeSet? _phonemes;

  SyllableElement? _target;
  SyllableElement? _answer;
  String _mode = 'rhyme';
  Phoneme? _onsetPhoneme;
  List<SyllableElement> _options = const [];
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _phonemes = await widget.contentService.loadPhonemes();
    for (final e in bank.elements) {
      _byId[e.id] = e;
    }
    _pool = bank.elements
        .where((e) =>
            e.picturable && (widget.allowedIds?.contains(e.id) ?? true))
        .toList(growable: false);
    for (final e in _pool) {
      final rg = e.rhymeGroup;
      if (rg != null) (_rhyme[rg] ??= []).add(e);
      final on = e.onsetPhoneme;
      if (on != null) (_onset[on] ??= []).add(e);
    }
    // A word is playable if it has ≥2 members in some family (itself + a match).
    _playable = _pool
        .where((e) => _familySize(e, 'rhyme') >= 2 || _familySize(e, 'onset') >= 2)
        .toList(growable: false);
    if (_playable.isNotEmpty) {
      setState(_startRound);
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  List<SyllableElement> _family(SyllableElement e, String mode) =>
      (mode == 'rhyme' ? _rhyme[e.rhymeGroup] : _onset[e.onsetPhoneme]) ??
      const [];
  int _familySize(SyllableElement e, String mode) => _family(e, mode).length;
  String? _familyKey(SyllableElement e, String mode) =>
      mode == 'rhyme' ? e.rhymeGroup : e.onsetPhoneme;

  SyllableElement? _focusElement() {
    if (_target != null) return null; // first round only
    for (final e in _playable) {
      if (e.id == widget.focusId) return e;
    }
    return null;
  }

  void _startRound() {
    resetRoundFlaws();
    final target = _focusElement() ??
        widget.sampler?.pick<SyllableElement>(
          _playable,
          id: (e) => e.id,
          stage: (e) => e.introducedStage,
          exclude: _target?.id,
        ) ??
        _playable[_random.nextInt(_playable.length)];

    final modes = [
      if (_familySize(target, 'rhyme') >= 2) 'rhyme',
      if (_familySize(target, 'onset') >= 2) 'onset',
    ];
    final mode = modes[_random.nextInt(modes.length)];
    final key = _familyKey(target, mode);

    final family =
        _family(target, mode).where((e) => e.id != target.id).toList();
    final answer = family[_random.nextInt(family.length)];

    // Distractors: outside this family (different rime / onset) and not the answer.
    final distractors = _pool.where((e) {
      if (e.id == target.id || e.id == answer.id) return false;
      return _familyKey(e, mode) != key;
    }).toList()
      ..shuffle(_random);

    _options = [answer, ...distractors.take(widget.optionCount - 1)]
      ..shuffle(_random);
    _target = target;
    _answer = answer;
    _mode = mode;
    _onsetPhoneme =
        mode == 'onset' ? _phonemes?.byIpa(target.onsetPhoneme ?? '') : null;
    _solved = false;
    _wrong = false;
    _playPrompt();
  }

  void _playPrompt() {
    final p = _onsetPhoneme;
    if (_mode == 'onset' && p != null) {
      // Stops can't be voiced alone — play the anchored/stretched onset sound.
      widget.audioService.speakPhoneme(p,
          anchorSyllable: _byId[p.anchor]?.syllable ?? p.ipa);
    } else if (_target != null) {
      // Rhyme mode names the task aloud so the child knows what to listen for.
      widget.audioService
          .speak('Tap the word that rhymes with ${_target!.syllable}.');
    }
  }

  void _onPick(SyllableElement picked) {
    if (_solved) return;
    final correct = picked.id == _answer!.id;
    widget.onEvent?.call(LearningEvent(
      itemId: _target!.id,
      skill: _mode, // 'rhyme' | 'onset'
      stage: 3,
      correct: correct,
      game: 'families',
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
      noteWrongAttempt();
      setState(() => _wrong = true);
      widget.audioService
          .speak('Oops! ${picked.syllable} does not match. Try again!');
    }
  }

  void _next() => setState(_startRound);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: const Text('Sound Families'),
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
          final target = _target;
          if (target == null) {
            return const Center(child: Text('Not enough words to play.'));
          }
          final onset = _mode == 'onset';
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  onset
                      ? 'Tap the word that starts the same'
                      : 'Tap the word that rhymes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                // Leading box mirrors the IconButton so the glyph is centered.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    GlyphView(target, size: 72),
                    IconButton(
                      key: const Key('fam-hear'),
                      onPressed: _playPrompt,
                      icon: const Icon(Icons.volume_up),
                      tooltip: 'Hear it',
                    ),
                  ],
                ),
                // Always occupy the hint line so rhyme rounds don't shift up.
                SizedBox(
                  height: 20,
                  child: onset && _onsetPhoneme != null
                      ? Text(
                          _onsetPhoneme!.stretchy
                              ? 'a stretchy sound — hold it'
                              : 'a pop sound — quick!',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                ),
                // Fixed-height slot: feedback never shoves the options around.
                FeedbackSlot(
                  child: _solved
                      ? Text('🎉 Yes!',
                          key: const Key('fam-feedback'),
                          style: Theme.of(context).textTheme.headlineSmall)
                      : _wrong
                          ? Text('Not that one — try again',
                              key: const Key('fam-wrong'),
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
                      for (final e in _options)
                        _OptionCard(
                          key: Key('fam-option-${e.id}'),
                          element: e,
                          dimmed: _solved && e.id != _answer!.id,
                          onTap: () => _onPick(e),
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
                      key: const Key('fam-next'),
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
    required this.element,
    required this.dimmed,
    required this.onTap,
  });

  final SyllableElement element;
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
          child: Center(child: GlyphView(element, size: 64)),
        ),
      ),
    );
  }
}
