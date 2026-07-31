import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/token_view.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../models/story.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';
import '../common/feedback_slot.dart';
import '../common/next_arrow_bar.dart';
import '../common/single_round.dart';

/// **Story Time** — a whole lesson node devoted to reading one longer
/// tap-along story composed of glyphs. The child taps each token of a line
/// LEFT TO RIGHT (hearing every one), the line is then read back fluently,
/// and the story advances line by line to the end — lines flow on the audio,
/// with no taps needed between them.
///
/// The child is NEVER quizzed: unknown glyphs are fine (tap-along is the
/// whole game), so there is no way to fail and every round is flawless.
/// Stories intentionally reach beyond the taught pool — meeting a not-yet
/// -taught glyph inside a story it can simply hear is part of the design.
class StoryTimePage extends StatefulWidget {
  const StoryTimePage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.level = 1,
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

  /// The child's curriculum level — picks which stories are unlocked.
  final int level;

  /// The child's current curriculum stage — drives how tokens are rendered.
  final int stage;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Kept for contract uniformity with the other games; Story Time reads a
  /// whole authored story (the story, not an item, is the unit), so it is
  /// deliberately unused.
  final ItemSampler? sampler;

  /// Kept for contract uniformity with the other games; deliberately unused —
  /// stories intentionally reach beyond the taught pool, and the child just
  /// taps along and listens.
  final Set<String>? allowedIds;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  /// Emits a [LearningEvent] once per finished story (the progression seam).
  final void Function(LearningEvent)? onEvent;

  /// Lesson-step mode: play one story, then auto-advance via [onRoundComplete]
  /// (no "next" arrow).
  final bool singleRound;

  /// Kept for contract uniformity with the other games; deliberately unused —
  /// a story is picked whole, never steered toward one focus element.
  final String? focusId;

  /// Reports round completion (always flawless — Story Time cannot be failed).
  final void Function({required bool flawless})? onRoundComplete;

  @override
  State<StoryTimePage> createState() => _StoryTimePageState();
}

class _StoryTimePageState extends State<StoryTimePage>
    with SingleRoundFlow<StoryTimePage> {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _elementById = {};
  List<Story> _stories = const [];

  Story? _story;
  int _lineIndex = 0;
  List<SyllableElement> _lineTokens = const [];
  int _readCount = 0;
  bool _storyDone = false;
  int _score = 0;
  String? _prevStoryId;

  /// Invalidates in-flight line-advance chains when a new story starts, so a
  /// stale readback can never advance the wrong story.
  int _round = 0;

  /// Ceiling on waiting for one utterance in the line-advance chain — a
  /// wedged TTS engine must never stall the story.
  static const Duration _speechGuard = Duration(seconds: 3);

  bool get _lineDone =>
      _lineTokens.isNotEmpty && _readCount == _lineTokens.length;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    final set = await widget.contentService.loadStories();
    // Playable stories: unlocked at this level, every token resolving to a
    // bank element (and no degenerate empty lines).
    _stories = set
        .unlockedAt(widget.level)
        .where((s) =>
            s.lines.isNotEmpty &&
            s.lines.every(
                (line) => line.isNotEmpty && line.every(_elementById.containsKey)))
        .toList(growable: false);
    if (_stories.isNotEmpty) {
      setState(_startRound);
      _speakInstruction();
    } else {
      skipUnplayableRound(widget.onRoundComplete);
    }
  }

  static const _instruction = 'Story time! Tap along with me.';
  void _speakInstruction() => widget.audioService.speak(_instruction);

  void _startRound() {
    // Tales grow with the reader: pick from the two NEWEST unlocks (the list
    // is newest-first), avoiding an immediate repeat when there is a choice.
    final recent = _stories.take(2).toList(growable: false);
    final fresh =
        recent.where((s) => s.id != _prevStoryId).toList(growable: false);
    final pool = fresh.isNotEmpty ? fresh : recent;
    final story = pool[_random.nextInt(pool.length)];
    _prevStoryId = story.id;
    _story = story;
    _lineIndex = 0;
    _lineTokens = _tokensOfLine(0);
    _readCount = 0;
    _storyDone = false;
    _round++;
    resetRoundFlaws();
  }

  List<SyllableElement> _tokensOfLine(int line) =>
      [for (final id in _story!.lines[line]) _elementById[id]!];

  Future<void> _speak(SyllableElement e) =>
      widget.audioService.speak(e.syllable);

  void _onTapToken(int index) {
    // Tap-to-hear is a hard app invariant: every token always speaks.
    final speech = _speak(_lineTokens[index]);
    // Only the expected (leftmost unread) token advances — no penalty else.
    if (_storyDone || _lineDone || index != _readCount) return;
    setState(() => _readCount += 1);
    if (_lineDone) _completeLine(afterLastWord: speech);
  }

  /// The line's last token was tapped: let it ring out ALONE, then read the
  /// whole line back fluently, and only when THAT has been heard advance to
  /// the next line — so the story flows on audio, no taps between lines.
  void _completeLine({required Future<void> afterLastWord}) {
    final round = _round;
    final lineText = _lineTokens.map((e) => e.syllable).join(' ');
    afterLastWord.timeout(_speechGuard, onTimeout: () {}).then((_) {
      if (!mounted || round != _round) return Future<void>.value();
      return widget.audioService
          .speak(lineText)
          .timeout(_speechGuard, onTimeout: () {});
    }).then((_) {
      if (!mounted || round != _round) return;
      if (_lineIndex + 1 < _story!.lines.length) {
        setState(() {
          _lineIndex += 1;
          _lineTokens = _tokensOfLine(_lineIndex);
          _readCount = 0;
        });
      } else {
        _completeStory();
      }
    });
  }

  void _completeStory() {
    setState(() {
      _storyDone = true;
      _score += 1;
    });
    final ending =
        widget.audioService.speak('The end! You read a whole story!');
    widget.onEvent?.call(LearningEvent(
      itemId: _story!.lines.first.first,
      skill: 'read',
      stage: widget.stage,
      correct: true,
      game: 'story_time',
    ));
    // Flawless is always true: noteWrongAttempt is never called here.
    scheduleRoundComplete(widget.onRoundComplete, afterSpeech: ending);
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
              title: const Text('Story Time'),
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
          if (_story == null) {
            return const Center(child: Text('No stories yet.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _dotsRow(),
                  const SizedBox(height: 24),
                  // The current line (full width ⇒ centering is unconditional).
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < _lineTokens.length; i++)
                          _tokenTile(i),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Fixed-height slot keeps the line steady when it appears.
                  FeedbackSlot(
                    child: _storyDone
                        ? Text('🎉 The end!',
                            key: const Key('st-feedback'),
                            style: Theme.of(context).textTheme.headlineSmall)
                        : null,
                  ),
                  const Spacer(),
                  // Big, always-present advance arrow — tappable at story end.
                  // A lesson step (singleRound) auto-advances instead.
                  if (!widget.singleRound)
                    NextArrowBar(
                      key: const Key('st-next'),
                      enabled: _storyDone,
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

  /// One progress dot per story line, filled once its line has been read —
  /// the child can SEE the tale advancing without any words.
  Widget _dotsRow() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      key: const Key('st-dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _story!.lines.length; i++)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lineFinished(i)
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              border: Border.all(color: scheme.primary, width: 1.5),
            ),
          ),
      ],
    );
  }

  bool _lineFinished(int line) =>
      _storyDone || line < _lineIndex || (line == _lineIndex && _lineDone);

  /// One tappable token. The next expected token carries a primary-color
  /// highlight border; already-read tokens get a filled look. Border width is
  /// constant so tokens never move as the highlight advances.
  Widget _tokenTile(int index) {
    final scheme = Theme.of(context).colorScheme;
    final read = index < _readCount;
    final expected = !_lineDone && index == _readCount;
    return GestureDetector(
      onTap: () => _onTapToken(index),
      child: Container(
        key: Key('st-token-$index'),
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
        child: TokenView(_lineTokens[index], stage: widget.stage, size: 60),
      ),
    );
  }
}
