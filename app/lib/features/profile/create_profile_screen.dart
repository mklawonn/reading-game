import 'package:flutter/material.dart';

import '../../profile/profile.dart';
import 'avatars.dart';

/// First-run (and "add profile") screen: choose an avatar + type a name. Calls
/// [onCreate] with the new profile; the caller persists it and loads its progress.
class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key, required this.onCreate, this.onBack});

  final void Function(Profile profile) onCreate;

  /// Shown as a back affordance when there are already profiles to return to.
  final VoidCallback? onBack;

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _name = TextEditingController();
  String _avatar = kAvatars.first.id;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    widget.onCreate(Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      avatar: _avatar,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Who's playing?"),
        backgroundColor: scheme.inversePrimary,
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Pick an avatar',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                for (final a in kAvatars)
                  GestureDetector(
                    key: Key('avatar-${a.id}'),
                    onTap: () => setState(() => _avatar = a.id),
                    child: Container(
                      width: 66,
                      height: 66,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerHighest,
                        border: Border.all(
                          color: _avatar == a.id
                              ? scheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child:
                          Text(a.emoji, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            TextField(
              key: const Key('profile-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Name', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('profile-start'),
              onPressed: _name.text.trim().isEmpty ? null : _submit,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Start playing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
