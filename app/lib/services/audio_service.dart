import 'package:flutter_tts/flutter_tts.dart';

import '../models/phoneme.dart';

/// Plays the sound of a symbol or word — the "tap to hear" primitive used in
/// every game and screen.
///
/// M0 uses on-device text-to-speech to speak the syllable text. When recorded
/// voiceover clips exist (M1+), a clip referenced by a Content Bank `audio_ref`
/// should be preferred, with TTS kept only as a fallback.
abstract class AudioService {
  Future<void> speak(String text);

  /// Cancels any in-flight playback. Called on context switches (e.g. leaving a
  /// level session) so audio never bleeds into the next screen.
  Future<void> stop();
}

class TtsAudioService implements AudioService {
  TtsAudioService();

  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _tts.setSpeechRate(0.4); // slow and clear for early learners
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _configured = true;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _ensureConfigured();
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();
}

/// Stop/continuant-aware phoneme playback — the "sound layer" (see
/// docs/curriculum.md). A stop (p,b,t,d,k,ɡ) cannot be voiced in isolation, so
/// we anchor it in a keyword the child knows ("/k/" → "key"); a continuant is
/// stretchable, so we play a held approximation. Implemented as an extension on
/// [AudioService.speak], so every implementation gets it for free and the audio
/// quality lifts automatically once recorded clips replace TTS — at which point
/// the stop branch becomes an onset-truncated clip and the continuant branch a
/// real isolated-stretched clip.
extension PhonemeSpeech on AudioService {
  Future<void> speakPhoneme(Phoneme phoneme, {required String anchorSyllable}) {
    if (phoneme.isStop) return speak(anchorSyllable);
    return speak(_stretchedTts[phoneme.ipa] ?? anchorSyllable);
  }
}

/// TTS-friendly "held" spellings for continuants — a placeholder until recorded
/// isolated-phoneme clips exist. Stops are intentionally absent (they route to
/// the keyword anchor). The canonical continuants-first set (s, f, m, n, ŋ) is
/// the most faithful here; vowels/glides are best-effort.
const Map<String, String> _stretchedTts = {
  's': 'ssss', 'f': 'ffff', 'h': 'hhh', 'm': 'mmmm', 'n': 'nnnn', 'ŋ': 'ngng',
  'l': 'llll', 'r': 'rrrr', 'w': 'wuh', 'æ': 'aaa', 'ɛ': 'ehh', 'ɪ': 'ihh',
  'ɒ': 'ahh', 'ʌ': 'uhh', 'iː': 'eee', 'ɔː': 'awww', 'eɪ': 'ayy', 'oʊ': 'ohh',
  'aʊ': 'oww', 'aɪ': 'eye', 'ɔɪ': 'oyy',
};
