import 'package:flutter_tts/flutter_tts.dart';

/// Thin wrapper around flutter_tts used by the Listening exercise to
/// synthesize real audio for the target phrase — no bundled voice
/// recordings needed, and no copyright concerns since nothing is
/// recorded from a third party.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> speak(String text, {String locale = 'es-ES'}) async {
    if (!_configured) {
      await _tts.setSpeechRate(0.42);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _configured = true;
    }
    try {
      await _tts.setLanguage(locale);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Best-effort: some platforms/environments (e.g. headless test
      // runners) have no TTS engine available. Failing silently keeps
      // the exercise usable via its on-screen text.
    }
  }

  void dispose() {
    _tts.stop();
  }
}
