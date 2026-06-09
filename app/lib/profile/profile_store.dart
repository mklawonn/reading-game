import 'profile.dart';

/// Persists the account's [ProfileData] (the profile list + active id). Mirrors
/// the `ProgressStore` abstraction; per-profile progress is stored separately,
/// keyed by profile id.
abstract interface class ProfileStore {
  Future<ProfileData> load();
  Future<void> save(ProfileData data);
}

/// In-memory store (tests / no backend). Keeps state for the session only.
class NoopProfileStore implements ProfileStore {
  NoopProfileStore([this._data = const ProfileData()]);
  ProfileData _data;

  @override
  Future<ProfileData> load() async => _data;

  @override
  Future<void> save(ProfileData data) async => _data = data;
}
