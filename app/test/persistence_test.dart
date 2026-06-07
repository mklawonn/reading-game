import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reading_game/models/content_bank.dart';
import 'package:reading_game/progress/local_progress_store.dart';
import 'package:reading_game/progress/progress_service.dart';
import 'package:reading_game/progress/progress_store.dart';

class _RecordingStore implements ProgressStore {
  _RecordingStore([this.initial]);
  final Map<String, dynamic>? initial;
  Map<String, dynamic>? saved;

  @override
  Future<Map<String, dynamic>?> load(String profileId) async => initial;

  @override
  Future<void> save(String profileId, Map<String, dynamic> data) async =>
      saved = data;
}

ContentBank _bank() => const ContentBank(
      version: '0',
      elements: [
        SyllableElement(
            id: 'cat', type: 'pictograph', syllable: 'cat', soundIpa: '', picturable: true),
      ],
      words: [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LocalProgressStore round-trips JSON', () async {
    SharedPreferences.setMockInitialValues({});
    const store = LocalProgressStore();
    expect(await store.load('default'), isNull);
    await store.save('default', {'xp': 42});
    expect((await store.load('default'))!['xp'], 42);
  });

  test('restore() loads saved progress into the service', () async {
    final store = _RecordingStore(const {
      'xp': 130,
      'unlocked': ['first_steps'],
      'mastery': {
        'cat': {'box': 4, 'correct': 4, 'seen': 4},
      },
      'skillCorrect': {'recognize': 4},
      'totalCorrect': 4,
      'totalAnswered': 4,
      'bestRun': 4,
      'dayStreak': 2,
      'lastDay': '2026-01-02',
    });
    final p = ProgressService(bank: _bank(), store: store);
    await p.restore();
    expect(p.xp, 130);
    expect(p.level, greaterThanOrEqualTo(2));
    expect(p.masteredCount, 1);
    expect(p.isUnlocked('first_steps'), isTrue);
  });

  test('flush() writes current progress to the store', () async {
    final store = _RecordingStore();
    final p = ProgressService(bank: _bank(), store: store);
    await p.flush();
    expect(store.saved, isNotNull);
    expect(store.saved!['xp'], 0);
  });
}
