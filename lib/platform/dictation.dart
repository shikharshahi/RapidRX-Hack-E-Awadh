import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../core/l10n/app_language.dart';

/// Speech to text, for what the doctor and the chemist said.
///
/// Speaking must produce text, or the feature is a lie (ADR-27): a recording
/// nobody can read does not cross-check against anything.
class Dictation {
  Dictation({SpeechToText? engine}) : _injected = engine;

  final SpeechToText? _injected;
  SpeechToText? _lazy;
  SpeechToText get _stt => _injected ?? (_lazy ??= SpeechToText());

  bool? _available;

  bool get listening => _available == true && _stt.isListening;

  /// Whether this device can dictate at all. Asked once.
  Future<bool> available() async {
    if (_available != null) return _available!;
    try {
      return _available = await _stt.initialize();
    } catch (_) {
      return _available = false;
    }
  }

  /// Listen until [onFinal] fires or [stop] is called. Partial results stream
  /// through [onWords] so the screen shows the words as they arrive.
  Future<bool> listen({
    required AppLanguage language,
    required void Function(String words, bool done) onWords,
  }) async {
    if (!await available()) return false;
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: language.locale.replaceAll('-', '_'),
          // A doctor explaining three medicines takes a while, and pauses
          // to think; six seconds of quiet is not the end of the visit.
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 6),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (r) => onWords(r.recognizedWords, r.finalResult),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    if (_available != true) return;
    try {
      await _stt.stop();
    } catch (_) {}
  }
}
