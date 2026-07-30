/// Emoji stand-ins for pictograph art (real line-art arrives with the asset
/// pipeline). Maps a Content Bank pictograph element `id` to a recognizable
/// emoji. Shared by the picture-based games so the picturable set lives in one
/// place. Only ids present here can appear as picture options.
const Map<String, String> kPictographEmoji = {
  'cat': '🐱',
  'hat': '🎩',
  'dog': '🐕',
  'pig': '🐷',
  'bug': '🐛',
  'bed': '🛏️',
  'pen': '🖊️',
  'hen': '🐔',
  'sun': '☀️',
  'fox': '🦊',
  'box': '📦',
  'pot': '🍲',
  'net': '🥅',
  'can': '🥫',
  'man': '👨',
  'pup': '🐶',
  'bee': '🐝',
  'key': '🔑',
  'ball': '⚽',
  'ring': '💍',
  'rain': '🌧️',
  'snow': '❄️',
  'cow': '🐄',
  'hand': '✋',
  'boy': '👦',
  'wind': '💨',
  'i': '👁️',
};

/// Pictographs a young child can't reliably tell apart at emoji fidelity
/// (two dog faces, two person faces, two food containers). Games must never
/// seat members of one group in the same round — when the voice asks for
/// "pup" and both 🐕 and 🐶 are on screen, the answer looks arbitrary and
/// the whole game reads as broken. Real art may shrink this list.
const List<Set<String>> kConfusablePictographs = [
  {'dog', 'pup'},
  {'man', 'boy'},
  {'can', 'pot'},
];

/// Whether two element ids are visually confusable ([kConfusablePictographs]).
bool confusablePictographs(String a, String b) {
  if (a == b) return false;
  for (final group in kConfusablePictographs) {
    if (group.contains(a) && group.contains(b)) return true;
  }
  return false;
}

/// Greedily extends [chosen] from [candidates] (already shuffled) with items
/// that aren't confusable with anything picked so far; tops up with leftovers
/// only if the pool can't fill [count] cleanly (never returns short when
/// enough candidates exist).
List<T> fillVisuallyDistinct<T>(
  List<T> chosen,
  Iterable<T> candidates,
  int count,
  String Function(T) idOf,
) {
  final skipped = <T>[];
  for (final c in candidates) {
    if (chosen.length >= count) break;
    if (chosen.every((p) => !confusablePictographs(idOf(p), idOf(c)))) {
      chosen.add(c);
    } else {
      skipped.add(c);
    }
  }
  for (final c in skipped) {
    if (chosen.length >= count) break;
    chosen.add(c);
  }
  return chosen;
}
