import 'package:flutter/material.dart';

import '../../profile/profile.dart';
import '../../services/audio_service.dart';
import 'avatars.dart';

/// First-run (and "add profile") screen: pick an avatar, optionally type a
/// name, go. A pre-reader can complete it alone — every step is narrated, the
/// avatar tap answers aloud, and the name is optional (it defaults to the
/// avatar's name, e.g. "Fox"); typing is a grown-up nicety, not a gate.
class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({
    super.key,
    required this.onCreate,
    this.onBack,
    this.audioService,
  });

  final void Function(Profile profile) onCreate;

  /// Shown as a back affordance when there are already profiles to return to.
  final VoidCallback? onBack;

  /// Narrates the screen when provided (null keeps old tests/hosts silent).
  final AudioService? audioService;

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _name = TextEditingController();
  String _avatar = kAvatars.first.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.audioService
        ?.speak('Who is playing? Pick your favorite animal!'));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _pickAvatar(Avatar a) {
    setState(() => _avatar = a.id);
    widget.audioService?.speak('${avatarName(a.id)}! Press the big button!');
  }

  void _submit() {
    final typed = _name.text.trim();
    widget.onCreate(Profile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: typed.isEmpty ? avatarName(_avatar) : typed,
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
                    onTap: () => _pickAvatar(a),
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
              decoration: InputDecoration(
                  labelText: 'Name (optional — grown-ups can type one)',
                  hintText: avatarName(_avatar),
                  border: const OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            // Always enabled: an avatar is preselected and the name defaults,
            // so the child can never dead-end here.
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                key: const Key('profile-start'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 44),
                label: Text(avatarEmoji(_avatar),
                    style: const TextStyle(fontSize: 30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
