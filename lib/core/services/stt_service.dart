import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around `speech_to_text`, mirroring [TtsService]'s shape —
/// this is real on-device speech recognition (not a self-report), used
/// by the Speaking exercise to grade pronunciation automatically.
class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  Future<bool> init() async {
    try {
      _available = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      // No mic/recognizer available on this platform/environment (e.g. a
      // headless test runner, or a denied permission) — fail closed.
      _available = false;
    }
    return _available;
  }

  /// Listens once and resolves with the recognized text, or `null` if
  /// the recognizer is unavailable, permission was denied, or nothing
  /// was heard before [timeout].
  Future<String?> listenOnce({
    String locale = 'es-ES',
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!_available && !await init()) return null;

    final completer = Completer<String?>();
    void complete(String? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) complete(result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          localeId: locale,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
        ),
      );
    } catch (_) {
      return null;
    }

    // Safety net in case the recognizer never delivers a final result.
    unawaited(
      Future<void>.delayed(timeout + const Duration(seconds: 1), () => complete(null)),
    );

    return completer.future;
  }

  void stop() => _speech.stop();

  void dispose() => _speech.cancel();
}
