import 'package:flutter/material.dart';

import 'progress_service.dart';

typedef AchievementTest = bool Function(ProgressService p);

@immutable
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.test,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementTest test;
}

// Predicates reference ONLY aggregates and stages — never specific content — so
// the curriculum can change without breaking achievements.
bool _firstSteps(ProgressService p) => p.totalCorrect >= 1;
bool _onARoll(ProgressService p) => p.bestRun >= 5;
bool _blender(ProgressService p) => p.skillCorrect('blend') >= 1;
bool _blendMaster(ProgressService p) => p.skillCorrect('blend') >= 10;
bool _collector5(ProgressService p) => p.masteredCount >= 5;
bool _collector15(ProgressService p) => p.masteredCount >= 15;
bool _stage1Half(ProgressService p) => p.stageProgress(1) >= 0.5;
bool _stage1Ready(ProgressService p) => p.stageProgress(1) >= 0.9;
bool _streak3(ProgressService p) => p.dayStreak >= 3;

/// The achievement set. Add a row here — no game or content changes needed.
const List<Achievement> kAchievements = [
  Achievement(
      id: 'first_steps',
      title: 'First Steps',
      description: 'Get your first one right',
      icon: Icons.flag,
      test: _firstSteps),
  Achievement(
      id: 'on_a_roll',
      title: 'On a Roll',
      description: 'Get 5 right in a row',
      icon: Icons.bolt,
      test: _onARoll),
  Achievement(
      id: 'blender',
      title: 'Word Builder',
      description: 'Blend your first word',
      icon: Icons.extension,
      test: _blender),
  Achievement(
      id: 'blend_master',
      title: 'Blend Master',
      description: 'Blend 10 words',
      icon: Icons.auto_awesome,
      test: _blendMaster),
  Achievement(
      id: 'collector_5',
      title: 'Collector',
      description: 'Master 5 symbols',
      icon: Icons.star,
      test: _collector5),
  Achievement(
      id: 'collector_15',
      title: 'Super Collector',
      description: 'Master 15 symbols',
      icon: Icons.stars,
      test: _collector15),
  Achievement(
      id: 'stage1_half',
      title: 'Halfway There',
      description: 'Master half of Stage 1',
      icon: Icons.trending_up,
      test: _stage1Half),
  Achievement(
      id: 'stage1_ready',
      title: 'Syllable Ready',
      description: 'Master Stage 1 — on to syllables!',
      icon: Icons.workspace_premium,
      test: _stage1Ready),
  Achievement(
      id: 'streak_3',
      title: '3-Day Streak',
      description: 'Play 3 days in a row',
      icon: Icons.local_fire_department,
      test: _streak3),
];
