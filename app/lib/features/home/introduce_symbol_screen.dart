import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../content/syllable_tile.dart';
import '../../models/content_bank.dart';
import '../../services/audio_service.dart';

/// "Meet this symbol" — the introduce-before-use step. Shows one big symbol,
/// plays its sound on arrival and on tap, then "Got it!" marks it seen. The
/// curriculum schedules one of these for every new symbol before any game uses it.
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

  /// Drop the page chrome (Scaffold AppBar) when hosted inside a level session.
  final bool embedded;

  @override
  State<IntroduceSymbolScreen> createState() => _IntroduceSymbolScreenState();
}

class _IntroduceSymbolScreenState extends State<IntroduceSymbolScreen> {
  @override
  void initState() {
    super.initState();
    // On arrival, name the symbol aloud ("This is a cat."); tapping it later
    // plays the clean syllable on its own for phonics.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.audioService.speak('This is ${widget.element.syllable}.'));
  }

  void _speak() => widget.audioService.speak(widget.element.syllable);

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
                onTap: _speak,
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
              // The written form too, so picture and letters are paired.
              SyllableTile(widget.element.syllable, fontSize: 32),
              const SizedBox(height: 8),
              IconButton(
                key: const Key('intro-hear'),
                iconSize: 32,
                onPressed: _speak,
                icon: const Icon(Icons.volume_up),
                tooltip: 'Hear it',
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('intro-done'),
                onPressed: widget.onDone,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
