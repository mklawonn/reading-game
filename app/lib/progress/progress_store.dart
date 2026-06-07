/// Where a profile's progress is persisted. Decoupled from [ProgressService] so
/// the backend can change (local ↔ Firestore) without touching the engine.
abstract class ProgressStore {
  Future<Map<String, dynamic>?> load(String profileId);
  Future<void> save(String profileId, Map<String, dynamic> data);
}

/// Persists nothing — the default (used in tests / when no store is wired).
class NoopProgressStore implements ProgressStore {
  const NoopProgressStore();

  @override
  Future<Map<String, dynamic>?> load(String profileId) async => null;

  @override
  Future<void> save(String profileId, Map<String, dynamic> data) async {}
}
