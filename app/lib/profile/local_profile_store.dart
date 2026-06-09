import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';
import 'profile_store.dart';

/// On-device profile list + active id (survives restarts). The default until a
/// cloud profile sync is wired; per-profile progress already syncs separately.
class LocalProfileStore implements ProfileStore {
  const LocalProfileStore();

  static const String _key = 'profiles';

  @override
  Future<ProfileData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const ProfileData();
    return ProfileData.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(ProfileData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(data.toJson()));
  }
}
