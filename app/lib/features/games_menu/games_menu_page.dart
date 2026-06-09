import 'package:flutter/material.dart';

import '../../profile/profile.dart';
import '../../progress/progress_service.dart';
import '../profile/avatars.dart';
import '../progress/progress_screen.dart';

/// One entry in the games menu. New play modes appear in the menu simply by
/// adding a [GameEntry] (in main.dart) — the menu itself stays generic.
class GameEntry {
  const GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;
}

/// The home launcher: a tappable list of every play mode, plus a level chip and
/// a button to the progress screen.
class GamesMenuPage extends StatelessWidget {
  const GamesMenuPage({
    super.key,
    required this.games,
    required this.progress,
    this.profile,
    this.onSwitchProfile,
  });

  final List<GameEntry> games;
  final ProgressService progress;
  final Profile? profile;
  final VoidCallback? onSwitchProfile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: profile == null
            ? null
            : IconButton(
                key: const Key('menu-profile'),
                tooltip: 'Switch player',
                onPressed: onSwitchProfile,
                icon: Text(avatarEmoji(profile!.avatar),
                    style: const TextStyle(fontSize: 24)),
              ),
        title: Text(profile?.name ?? 'Reading Game'),
        backgroundColor: scheme.inversePrimary,
        actions: [
          ListenableBuilder(
            listenable: progress,
            builder: (context, _) => Center(
              child: Text('Lv ${progress.level}',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
          IconButton(
            key: const Key('menu-progress'),
            icon: const Icon(Icons.emoji_events),
            tooltip: 'My progress',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProgressScreen(progress: progress),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: games.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final game = games[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                key: Key('menu-game-$index'),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(game.icon, color: scheme.onPrimaryContainer),
                ),
                title: Text(game.title,
                    style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text(game.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: game.builder),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
