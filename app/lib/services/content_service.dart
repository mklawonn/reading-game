import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/content_bank.dart';

/// Loads the bundled Content Bank. Subclass and override [load] in tests to
/// inject an in-memory bank instead of reading the asset.
class ContentService {
  const ContentService();

  static const String assetPath = 'assets/content/content_bank.v1.json';

  Future<ContentBank> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return ContentBank.fromJson(json.decode(raw) as Map<String, dynamic>);
  }
}
