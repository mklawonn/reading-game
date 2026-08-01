import 'package:flutter/material.dart';

import '../../progress/achievements.dart';
import '../../progress/progress_service.dart';
import 'level_map_screen.dart';

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
              Text('Your journey', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              LevelMap(progress: progress),
              const SizedBox(height: 8),
              _LevelSummary(progress: progress),
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
              const SizedBox(height: 32),
              // Parent-facing escape hatch: wipe this player back to Level 1.
              // Deliberately wordy and double-confirmed — a child mashing
              // around in here must not be able to erase themselves.
              Center(
                child: OutlinedButton.icon(
                  key: const Key('progress-reset'),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Start over (erases all progress)'),
                  onPressed: () => _confirmReset(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text(
            'This erases ALL of this player\'s progress — levels, stars, and '
            'mastered words — and cannot be undone. (Grown-ups only!)'),
        actions: [
          TextButton(
            key: const Key('reset-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep my progress'),
          ),
          TextButton(
            key: const Key('reset-confirm'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Erase everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await progress.reset();
      if (context.mounted) Navigator.of(context).pop(); // back to the journey
    }
  }
}

class _LevelSummary extends StatelessWidget {
  const _LevelSummary({required this.progress});

  final ProgressService progress;

  @override
  Widget build(BuildContext context) {
    // Levels advance by completed lessons (docs/lessons.md); total XP is the
    // rewards-layer stat and reads as a plain total, never "X / Y".
    return Column(
      children: [
        Text('Level ${progress.level}',
            style: Theme.of(context).textTheme.titleLarge),
        Text(
            '🔥 ${progress.dayStreak}-day streak   ·   ⭐ ${progress.masteredCount} mastered',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 2),
        Text(
            '${progress.lessonsIntoLevel} of ${progress.lessonsForThisLevel} '
            'lessons this level   ·   ${progress.xp} XP total',
            style: Theme.of(context).textTheme.bodySmall),
      ],
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
