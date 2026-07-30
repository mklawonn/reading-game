import 'dart:async';

import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/syllable_tile.dart';
import '../../models/content_bank.dart';
import '../../services/audio_service.dart';

/// Ids whose names don't take "a" ("This is rain", not "This is a rain").
const Set<String> _noArticle = {'rain', 'snow', 'wind', 'i', 'see'};

/// "Meet this symbol" — the introduce-before-use step. Shows one big symbol,
/// names it aloud on arrival (and again shortly after, in case a stray tap
/// talked over the introduction), then a big ✓ marks it met. Tapping the
/// picture or the word repeats the line; the small speaker plays the clean
/// bare syllable for phonics.
class IntroduceSymbolScreen extends StatefulWidget {
  const IntroduceSymbolScreen({
    super.key,
    required this.element,
    required this.audioService,
    required this.onDone,
    this.embedded = false,
  });

  final SyllableElement element;
  final AudioService audioService;
  final VoidCallback onDone;

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a lesson.
  final bool embedded;

  @override
  State<IntroduceSymbolScreen> createState() => _IntroduceSymbolScreenState();
}

class _IntroduceSymbolScreenState extends State<IntroduceSymbolScreen> {
  Timer? _respeak;
  bool _interacted = false;

  String get _introLine {
    final e = widget.element;
    final article = e.picturable && !_noArticle.contains(e.id) ? ' a' : '';
    return 'This is$article ${e.syllable}!';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.audioService.speak(_introLine));
    // The teaching moment must not be losable: if a stray tap during the
    // previous screen's transition talked over the line and the child hasn't
    // touched anything, say it once more.
    _respeak = Timer(const Duration(seconds: 4), () {
      if (mounted && !_interacted) widget.audioService.speak(_introLine);
    });
  }

  @override
  void dispose() {
    _respeak?.cancel();
    super.dispose();
  }

  void _speakLine() {
    _interacted = true;
    widget.audioService.speak(_introLine);
  }

  void _speakBare() {
    _interacted = true;
    widget.audioService.speak(widget.element.syllable);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.embedded ? null : AppBar(
        title: const Text('New symbol!'),
        backgroundColor: scheme.inversePrimary,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Say hello to', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              GestureDetector(
                key: const Key('intro-symbol'),
                onTap: _speakLine,
                child: Container(
                  width: 180,
                  height: 180,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: GlyphView(widget.element, size: 120),
                ),
              ),
              const SizedBox(height: 16),
              // The written form too, so picture and letters are paired —
              // tappable, because children tap the big things.
              GestureDetector(
                key: const Key('intro-word'),
                onTap: _speakLine,
                child: SyllableTile(widget.element.syllable, fontSize: 32),
              ),
              const SizedBox(height: 8),
              IconButton(
                key: const Key('intro-hear'),
                iconSize: 32,
                onPressed: _speakBare,
                icon: const Icon(Icons.volume_up),
                tooltip: 'Hear it',
              ),
              const SizedBox(height: 24),
              // A picture button, not words — the audience can't read yet.
              SizedBox(
                width: 160,
                height: 68,
                child: FilledButton(
                  key: const Key('intro-done'),
                  onPressed: widget.onDone,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22)),
                  ),
                  child: const Icon(Icons.check_rounded, size: 40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
