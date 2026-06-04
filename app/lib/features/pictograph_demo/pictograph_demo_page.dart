import 'package:flutter/material.dart';

import '../../models/content_bank.dart';
import '../../services/audio_service.dart';
import '../../services/content_service.dart';

/// Stage-1 demo: a grid of pictograph "cards". Tapping a card plays its sound —
/// proving the Content Bank → UI → audio loop that underpins every game.
class PictographDemoPage extends StatefulWidget {
  const PictographDemoPage({
    super.key,
    required this.contentService,
    required this.audioService,
  });

  final ContentService contentService;
  final AudioService audioService;

  @override
  State<PictographDemoPage> createState() => _PictographDemoPageState();
}

class _PictographDemoPageState extends State<PictographDemoPage> {
  late final Future<ContentBank> _bankFuture = widget.contentService.load();
  String? _lastTappedId;

  Future<void> _onTap(SyllableElement element) async {
    setState(() => _lastTappedId = element.id);
    await widget.audioService.speak(element.syllable);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to hear'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FutureBuilder<ContentBank>(
        future: _bankFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load content: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pictographs = snapshot.data!.pictographs;
          return SafeArea(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: pictographs.length,
              itemBuilder: (context, index) {
                final element = pictographs[index];
                return _PictographCard(
                  element: element,
                  highlighted: element.id == _lastTappedId,
                  onTap: () => _onTap(element),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PictographCard extends StatelessWidget {
  const _PictographCard({
    required this.element,
    required this.highlighted,
    required this.onTap,
  });

  final SyllableElement element;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Placeholder "card": a rounded frame showing the syllable text. Real
    // pictograph art (image_ref) replaces the text in M1; tap-to-hear is unchanged.
    return Semantics(
      button: true,
      label: 'Play the sound ${element.syllable}',
      child: Material(
        color: highlighted ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                element.syllable,
                style: Theme.of(context)
                    .textTheme
                    .displaySmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Icon(Icons.volume_up, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
