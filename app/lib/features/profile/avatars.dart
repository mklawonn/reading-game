/// A pickable avatar — no photos or PII. Rendered as a big emoji for now; map
/// the id to an illustration asset later without touching stored profiles.
class Avatar {
  const Avatar(this.id, this.emoji);
  final String id;
  final String emoji;
}

const List<Avatar> kAvatars = [
  Avatar('fox', '🦊'),
  Avatar('cat', '🐱'),
  Avatar('dog', '🐶'),
  Avatar('bee', '🐝'),
  Avatar('owl', '🦉'),
  Avatar('frog', '🐸'),
  Avatar('panda', '🐼'),
  Avatar('lion', '🦁'),
  Avatar('penguin', '🐧'),
  Avatar('unicorn', '🦄'),
  Avatar('dino', '🦕'),
  Avatar('robot', '🤖'),
];

String avatarEmoji(String id) {
  for (final a in kAvatars) {
    if (a.id == id) return a.emoji;
  }
  return '🙂';
}
