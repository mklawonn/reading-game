import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/content_bank.dart';
import '../models/curriculum.dart';
import '../models/phoneme.dart';
import '../models/phrase.dart';
import '../models/story.dart';

/// Loads the bundled Content Bank and phrase set. Subclass and override [load]
/// / [loadPhrases] in tests to inject in-memory data instead of reading assets.
class ContentService {
  const ContentService();

  static const String assetPath = 'assets/content/content_bank.v1.json';
  static const String phrasesAssetPath = 'assets/content/phrases.v1.json';
  static const String phonemesAssetPath = 'assets/content/phonemes.v1.json';
  static const String curriculumAssetPath = 'assets/content/curriculum.v1.json';
  static const String storiesAssetPath = 'assets/content/stories.v1.json';

  Future<ContentBank> load() async {
    final raw = await rootBundle.loadString(assetPath);
    return ContentBank.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<PhraseSet> loadPhrases() async {
    final raw = await rootBundle.loadString(phrasesAssetPath);
    return PhraseSet.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<PhonemeSet> loadPhonemes() async {
    final raw = await rootBundle.loadString(phonemesAssetPath);
    return PhonemeSet.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<CurriculumSchedule> loadCurriculum() async {
    final raw = await rootBundle.loadString(curriculumAssetPath);
    return CurriculumSchedule.fromJson(json.decode(raw) as Map<String, dynamic>);
  }

  Future<StorySet> loadStories() async {
    final raw = await rootBundle.loadString(storiesAssetPath);
    return StorySet.fromJson(json.decode(raw) as Map<String, dynamic>);
  }
}
