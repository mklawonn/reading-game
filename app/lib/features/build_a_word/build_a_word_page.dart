import 'dart:math';

import 'package:flutter/material.dart';

import '../../content/pictograph_emoji.dart';
import '../../content/syllable_tile.dart';
import '../../learning/item_sampler.dart';
import '../../models/content_bank.dart';
import '../../progress/learning_event.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';

class _Piece {
  const _Piece(this.token, this.element);
  final int token;
  final SyllableElement element;
}

/// **Build-a-Word** (Stage 2): the core syllabary blending mechanic. The target
/// word is shown and heard; the child drags (or taps) scattered syllable cards
/// into ordered slots to blend them into the word — e.g. `o` + `pen` → `open`.
class BuildAWordPage extends StatefulWidget {
  const BuildAWordPage({
    super.key,
    required this.contentService,
    required this.audioService,
    this.random,
    this.sampler,
    this.onEvent,
  });

  final ContentService contentService;
  final AudioService audioService;

  /// Inject a seeded [Random] in tests for determinism.
  final Random? random;

  /// Mastery-driven target selection. When null, falls back to uniform random.
  final ItemSampler? sampler;

  /// Emits a [LearningEvent] on each answer (the progression seam).
  final void Function(LearningEvent)? onEvent;

  @override
  State<BuildAWordPage> createState() => _BuildAWordPageState();
}

class _BuildAWordPageState extends State<BuildAWordPage> {
  late final Random _random = widget.random ?? Random();
  late final Future<void> _ready = _load();

  final Map<String, SyllableElement> _elementById = {};
  List<SyllableElement> _allElements = const [];
  List<Word> _buildable = const [];

  late Word _word;
  String? _prevWordId;
  List<_Piece> _scatter = [];
  List<_Piece?> _slots = [];
  int _nextToken = 0;
  bool _solved = false;
  bool _wrong = false;
  int _score = 0;

  Future<void> _load() async {
    final bank = await widget.contentService.load();
    _allElements = bank.elements;
    for (final e in bank.elements) {
      _elementById[e.id] = e;
    }
    // Buildable = taught blends of 2–3 known syllables.
    _buildable = bank.words
        .where((w) =>
            !w.isTestBlend &&
            w.segmentation.length >= 2 &&
            w.segmentation.length <= 3 &&
            w.segmentation.every(_elementById.containsKey))
        .toList(growable: false);
    if (_buildable.isNotEmpty) {
      _startRound();
      widget.audioService.speak(_word.text);
    }
  }

  // A blend's stage = the latest stage among its component syllables.
  int _wordStage(Word w) => w.segmentation
      .map((id) => _elementById[id]?.introducedStage ?? 2)
      .fold(1, (a, b) => a > b ? a : b);

  void _startRound() {
    _word = widget.sampler?.pick<Word>(
          _buildable,
          id: (w) => w.id,
          stage: _wordStage,
          exclude: _prevWordId,
        ) ??
        _buildable[_random.nextInt(_buildable.length)];
    _prevWordId = _word.id;
    final pieces = <_Piece>[
      for (final id in _word.segmentation) _Piece(_nextToken++, _elementById[id]!),
    ];
    // One distractor piece (a syllable not in this word) to make it non-trivial.
    final distractors = _allElements
        .where((e) => !_word.segmentation.contains(e.id))
        .toList()
      ..shuffle(_random);
    if (distractors.isNotEmpty) {
      pieces.add(_Piece(_nextToken++, distractors.first));
    }
    pieces.shuffle(_random);
    _scatter = pieces;
    _slots = List<_Piece?>.filled(_word.segmentation.length, null);
    _solved = false;
    _wrong = false;
  }

  void _placeInSlot(_Piece piece, int index) {
    if (_solved || _slots[index] != null) return;
    setState(() {
      _slots[index] = piece;
      _scatter.remove(piece);
      _wrong = false;
    });
    _check();
  }

  void _placeNext(_Piece piece) {
    final index = _slots.indexWhere((s) => s == null);
    if (index != -1) _placeInSlot(piece, index);
  }

  void _removeFromSlot(int index) {
    final piece = _slots[index];
    if (_solved || piece == null) return;
    setState(() {
      _slots[index] = null;
      _scatter.add(piece);
      _wrong = false;
    });
  }

  void _check() {
    if (_slots.any((s) => s == null)) return;
    final built = [for (final s in _slots) s!.element.id];
    final correct = _listEquals(built, _word.segmentation);
    widget.onEvent?.call(LearningEvent(
      itemId: _word.id,
      skill: 'blend',
      stage: 2,
      correct: correct,
      game: 'build_a_word',
    ));
    setState(() {
      if (correct) {
        _solved = true;
        _score += 1;
      } else {
        _wrong = true;
      }
    });
    if (correct) widget.audioService.speak(_word.text);
  }

  void _next() {
    setState(_startRound);
    widget.audioService.speak(_word.text);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _glyph(SyllableElement e) => kPictographEmoji[e.id] ?? e.syllable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Build a Word'),
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
          if (_buildable.isEmpty) {
            return const Center(child: Text('No buildable words available.'));
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Make this word', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(_word.text,
                      key: const Key('bw-target'),
                      style: Theme.of(context).textTheme.displaySmall),
                  FilledButton.icon(
                    key: const Key('bw-hear'),
                    onPressed: () => widget.audioService.speak(_word.text),
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Hear it'),
                  ),
                  const SizedBox(height: 16),
                  // Ordered slots.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slots.length; i++) ...[
                        _Slot(
                          index: i,
                          glyph: _slots[i] == null ? null : _glyph(_slots[i]!.element),
                          onAccept: (piece) => _placeInSlot(piece, i),
                          onTap: () => _removeFromSlot(i),
                        ),
                        if (i < _slots.length - 1)
                          const Icon(Icons.add, size: 20),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_wrong)
                    Text('Not yet — try again',
                        key: const Key('bw-wrong'),
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  if (_solved)
                    Column(
                      key: const Key('bw-feedback'),
                      children: [
                        Text('🎉 ${_word.text}!',
                            style: Theme.of(context).textTheme.headlineSmall),
                        FilledButton(
                          key: const Key('bw-next'),
                          onPressed: _next,
                          child: const Text('Next'),
                        ),
                      ],
                    ),
                  const Spacer(),
                  // Scattered, draggable pieces.
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final piece in _scatter)
                        _DraggablePiece(
                          key: Key('bw-piece-${piece.element.id}'),
                          piece: piece,
                          glyph: _glyph(piece.element),
                          onTap: () => _placeNext(piece),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.glyph, this.faded = false});
  final String glyph;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final isEmoji = glyph.isNotEmpty && glyph.runes.first > 0x2000;
    return Opacity(
      opacity: faded ? 0.3 : 1,
      child: Container(
        width: 96,
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: isEmoji
            ? Text(glyph,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold))
            : SyllableTile(glyph, fontSize: 28),
      ),
    );
  }
}

class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({
    super.key,
    required this.piece,
    required this.glyph,
    required this.onTap,
  });

  final _Piece piece;
  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chip = _Chip(glyph: glyph);
    return Draggable<_Piece>(
      data: piece,
      feedback: Material(color: Colors.transparent, child: chip),
      childWhenDragging: _Chip(glyph: glyph, faded: true),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: chip,
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.index,
    required this.glyph,
    required this.onAccept,
    required this.onTap,
  });

  final int index;
  final String? glyph;
  final ValueChanged<_Piece> onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<_Piece>(
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidate, rejected) {
        final filled = glyph != null;
        final isEmoji = filled && glyph!.isNotEmpty && glyph!.runes.first > 0x2000;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            key: Key('bw-slot-$index'),
            width: 96,
            height: 96,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: candidate.isNotEmpty
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant, width: 2),
            ),
            child: !filled
                ? null
                : isEmoji
                    ? Text(glyph!,
                        style: const TextStyle(
                            fontSize: 48, fontWeight: FontWeight.bold))
                    : SyllableTile(glyph!, fontSize: 28),
          ),
        );
      },
    );
  }
}
