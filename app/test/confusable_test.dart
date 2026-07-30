import 'package:flutter_test/flutter_test.dart';

import 'package:reading_game/content/pictograph_emoji.dart';

void main() {
  test('confusable pairs are symmetric and self-safe', () {
    expect(confusablePictographs('dog', 'pup'), isTrue);
    expect(confusablePictographs('pup', 'dog'), isTrue);
    expect(confusablePictographs('man', 'boy'), isTrue);
    expect(confusablePictographs('can', 'pot'), isTrue);
    expect(confusablePictographs('dog', 'dog'), isFalse);
    expect(confusablePictographs('cat', 'dog'), isFalse);
  });

  test('fillVisuallyDistinct never seats look-alikes when it can avoid it', () {
    final picked = fillVisuallyDistinct<String>(
        ['pup'], ['dog', 'cat', 'sun'], 3, (s) => s);
    expect(picked, ['pup', 'cat', 'sun']); // dog skipped as pup's look-alike
  });

  test('fillVisuallyDistinct tops up with leftovers rather than run short', () {
    final picked =
        fillVisuallyDistinct<String>(['pup'], ['dog'], 2, (s) => s);
    expect(picked, ['pup', 'dog']); // degenerate pool: full board beats fair
  });

  test('every confusable id has art, so groups reflect real screens', () {
    for (final group in kConfusablePictographs) {
      for (final id in group) {
        expect(kPictographEmoji.containsKey(id), isTrue, reason: id);
      }
    }
  });
}
