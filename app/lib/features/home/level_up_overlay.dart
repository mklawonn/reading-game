import 'package:flutter/material.dart';

import '../../content/glyph_view.dart';
import '../../models/content_bank.dart';
import '../../models/curriculum.dart';

/// Celebratory pop-in shown when the child reaches a new curriculum level —
/// names the level and previews the symbols it unlocks. No extra dependencies.
Future<void> showLevelUp(
  BuildContext context, {
  required CurriculumLevel level,
  required List<SyllableElement> newSymbols,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _LevelUpDialog(level: level, newSymbols: newSymbols),
  );
}

class _LevelUpDialog extends StatelessWidget {
  const _LevelUpDialog({required this.level, required this.newSymbols});

  final CurriculumLevel level;
  final List<SyllableElement> newSymbols;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Dialog(
        backgroundColor: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 56)),
              Text('Level ${level.id}!',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(level.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium),
              if (newSymbols.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text('New friends to meet',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [for (final s in newSymbols) GlyphView(s, size: 44)],
                ),
              ],
              const SizedBox(height: 22),
              FilledButton(
                key: const Key('levelup-continue'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text('Keep going!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
