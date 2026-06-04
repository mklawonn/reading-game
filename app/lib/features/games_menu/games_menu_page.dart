import 'package:flutter/material.dart';

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

/// The home launcher: a tappable list of every play mode.
class GamesMenuPage extends StatelessWidget {
  const GamesMenuPage({super.key, required this.games});

  final List<GameEntry> games;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Game'),
        backgroundColor: scheme.inversePrimary,
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
