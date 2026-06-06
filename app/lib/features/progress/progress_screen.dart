import 'package:flutter/material.dart';

import '../../progress/achievements.dart';
import '../../progress/progress_service.dart';

// Stage display names are a stable curriculum abstraction (not content).
const Map<int, String> _stageNames = {
  1: 'Pictographs',
  2: 'Syllables',
  3: 'Phonemes',
  4: 'Letters',
};

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, required this.progress});

  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Progress'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LevelCard(progress: progress),
              const SizedBox(height: 20),
              Text('Stage progress', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final s in progress.stages)
                _StageBar(stage: s, name: _stageNames[s] ?? 'Stage $s', value: progress.stageProgress(s)),
              const SizedBox(height: 20),
              Text('Achievements', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  for (final a in kAchievements)
                    _Badge(achievement: a, unlocked: progress.isUnlocked(a.id)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.progress});

  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final into = progress.xpIntoLevel;
    final span = progress.xpForThisLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  child: Text('${progress.level}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Level ${progress.level}',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('🔥 ${progress.dayStreak}-day streak   ·   ⭐ ${progress.masteredCount} mastered'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: span == 0 ? 0 : into / span,
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text('$into / $span XP to level ${progress.level + 1}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StageBar extends StatelessWidget {
  const _StageBar({required this.stage, required this.name, required this.value});

  final int stage;
  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Stage $stage · $name'),
              Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: value, minHeight: 10),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.unlocked});

  final Achievement achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: unlocked ? 1 : 0.4,
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  unlocked ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              child: Icon(achievement.icon,
                  color: unlocked ? scheme.onPrimaryContainer : scheme.outline),
            ),
            const SizedBox(height: 6),
            Text(achievement.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
