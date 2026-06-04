import 'package:flutter_tts/flutter_tts.dart';

/// Plays the sound of a symbol or word — the "tap to hear" primitive used in
/// every game and screen.
///
/// M0 uses on-device text-to-speech to speak the syllable text. When recorded
/// voiceover clips exist (M1+), a clip referenced by a Content Bank `audio_ref`
/// should be preferred, with TTS kept only as a fallback.
abstract class AudioService {
  Future<void> speak(String text);
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
}
