import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/app_language.dart';
import 'kokoro_tts.dart';

/// Something that can say a sentence out loud, and be stopped.
abstract class SpeechEngine {
  /// Returns false when this engine could not speak the sentence, so the next
  /// one in the chain can try.
  Future<bool> speak(String text, AppLanguage language);
  Future<void> stop();
}

/// Kokoro audio, played through `audioplayers`.
class KokoroEngine implements SpeechEngine {
  KokoroEngine({KokoroTts? tts, AudioPlayer? player})
    : _tts = tts ?? KokoroTts(),
      _injectedPlayer = player;

  final KokoroTts _tts;
  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _lazyPlayer;
  AudioPlayer get _player => _injectedPlayer ?? (_lazyPlayer ??= AudioPlayer());

  KokoroTts get tts => _tts;

  @override
  Future<bool> speak(String text, AppLanguage language) async {
    final bytes = await _tts.synthesize(text, language);
    if (bytes == null) return false;
    try {
      await _player.stop();
      final path = await _tts.cache.pathFor(
        KokoroTts.cacheKey(text, language, 1.0),
      );
      if (path != null) {
        await _player.play(DeviceFileSource(path));
      } else {
        await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() async {
    if (_injectedPlayer == null && _lazyPlayer == null) return;
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// The phone's own TTS. A fallback: robotic, and often without a Hindi voice.
class DeviceTtsEngine implements SpeechEngine {
  FlutterTts? _lazy;
  FlutterTts get _tts => _lazy ??= FlutterTts();

  final _supported = <AppLanguage, bool>{};

  @override
  Future<bool> speak(String text, AppLanguage language) async {
    try {
      if (!await _supports(language)) return false;
      await _tts.setLanguage(language.locale);
      await _tts.setSpeechRate(.45);
      await _tts.speak(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// `getLanguages` returns empty on the first call on the web, which once made
  /// the app announce "no voice" on a browser that had one. Consult the voices
  /// too, and when both are empty, try anyway.
  Future<bool> _supports(AppLanguage language) async {
    final known = _supported[language];
    if (known != null) return known;
    try {
      final languages = (await _tts.getLanguages as List?) ?? const [];
      final voices = (await _tts.getVoices as List?) ?? const [];
      if (languages.isEmpty && voices.isEmpty) return true; // optimistic
      final code = language.code;
      bool matches(Object? v) =>
          v.toString().toLowerCase().replaceAll('_', '-').startsWith(code);
      final ok =
          languages.any(matches) ||
          voices.any((v) => v is Map && matches(v['locale']));
      return _supported[language] = ok;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> stop() async {
    if (_lazy == null) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Kokoro, then the device, then silence. Silence beats a wrong accent reading
/// the wrong screen.
class ChainEngine implements SpeechEngine {
  ChainEngine(this.engines);

  final List<SpeechEngine> engines;

  @override
  Future<bool> speak(String text, AppLanguage language) async {
    for (final e in engines) {
      if (await e.speak(text, language)) return true;
    }
    return false;
  }

  @override
  Future<void> stop() async {
    for (final e in engines) {
      await e.stop();
    }
  }
}
