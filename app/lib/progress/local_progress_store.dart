import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'progress_store.dart';

/// On-device persistence (survives app restarts) with no backend — the default
/// until Firebase is configured.
class LocalProgressStore implements ProgressStore {
  const LocalProgressStore();

  String _key(String profileId) => 'progress.$profileId';

  @override
  Future<Map<String, dynamic>?> load(String profileId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(profileId));
    if (raw == null) return null;
    return json.decode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> save(String profileId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(profileId), json.encode(data));
  }
}
