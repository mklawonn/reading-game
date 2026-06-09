import 'package:flutter/material.dart';

import '../../profile/profile.dart';
import 'avatars.dart';

/// Launch chooser when profiles already exist: tap a player to load them, or add
/// a new one.
class ProfileChooserScreen extends StatelessWidget {
  const ProfileChooserScreen({
    super.key,
    required this.profiles,
    required this.onSelect,
    required this.onAdd,
  });

  final List<Profile> profiles;
  final void Function(Profile profile) onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a player'),
        backgroundColor: scheme.inversePrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final p in profiles)
              Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  key: Key('choose-${p.id}'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(avatarEmoji(p.avatar),
                        style: const TextStyle(fontSize: 28)),
                  ),
                  title: Text(p.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  onTap: () => onSelect(p),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('choose-add'),
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Padding(
                padding: EdgeInsets.all(10),
                child: Text('Add a player'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
