import 'package:flutter/material.dart';

import '../../profile/profile.dart';
import '../../services/audio_service.dart';
import 'avatars.dart';

/// Launch chooser when profiles already exist: tap a player to load them, or add
/// a new one. Narrated, because the players it lists can't read their own names.
class ProfileChooserScreen extends StatefulWidget {
  const ProfileChooserScreen({
    super.key,
    required this.profiles,
    required this.onSelect,
    required this.onAdd,
    this.audioService,
  });

  final List<Profile> profiles;
  final void Function(Profile profile) onSelect;
  final VoidCallback onAdd;

  /// Narrates the screen when provided (null keeps old tests/hosts silent).
  final AudioService? audioService;

  @override
  State<ProfileChooserScreen> createState() => _ProfileChooserScreenState();
}

class _ProfileChooserScreenState extends State<ProfileChooserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.audioService
        ?.speak('Who is playing today? Tap your picture!'));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profiles = widget.profiles;
    final onSelect = widget.onSelect;
    final onAdd = widget.onAdd;
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
