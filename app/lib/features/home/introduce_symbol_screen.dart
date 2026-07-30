import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/syllable_tile.dart';
import '../../models/content_bank.dart';
import '../../services/audio_service.dart';

/// Ids whose names don't take "a" ("This is rain", not "This is a rain").
const Set<String> _noArticle = {'rain', 'snow', 'wind', 'i', 'see'};

/// "Meet this symbol" — the introduce-before-use step, taught in **two beats**
/// so the print link is an explicit lesson, not set dressing:
///
///  1. the picture alone: "This is a cat!" — the thing and its name;
///  2. the written word slides in underneath: "And this says cat!" — the
///     print that *says* that name (one linked chunk, never letter-by-letter:
///     the syllable is the unit at this stage — see docs/curriculum.md).
///
/// Tapping the picture repeats beat 1, tapping the word repeats beat 2, the
/// small speaker plays the clean bare syllable, and the big ✓ marks it met.
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
  bool _wordRevealed = false;

  String get _introLine {
    final e = widget.element;
    final article = e.picturable && !_noArticle.contains(e.id) ? ' a' : '';
    return 'This is$article ${e.syllable}!';
  }

  String get _saysLine => 'And this says ${widget.element.syllable}!';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Beat 1 rings out fully, then beat 2 reveals the print. The timeout
      // keeps the reveal coming even if the TTS engine wedges.
      widget.audioService
          .speak(_introLine)
          .timeout(const Duration(seconds: 4), onTimeout: () {})
          .then((_) {
        if (!mounted || _wordRevealed) return;
        setState(() => _wordRevealed = true);
        widget.audioService.speak(_saysLine);
      });
    });
  }

  void _speakIntro() => widget.audioService.speak(_introLine);

  void _speakSays() => widget.audioService.speak(_saysLine);

  void _speakBare() => widget.audioService.speak(widget.element.syllable);

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
                onTap: _speakIntro,
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
              // Beat 2: the written form — space is reserved from the start so
              // the reveal never shoves the board around.
              SizedBox(
                height: 56,
                child: AnimatedSlide(
                  offset: _wordRevealed ? Offset.zero : const Offset(0, 0.4),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: _wordRevealed ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: GestureDetector(
                      key: const Key('intro-word'),
                      onTap: _speakSays,
                      child: SyllableTile(widget.element.syllable, fontSize: 32),
                    ),
                  ),
                ),
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
