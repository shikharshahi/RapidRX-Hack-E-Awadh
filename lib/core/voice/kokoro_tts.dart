import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../l10n/app_language.dart';
import 'voice_cache.dart';

/// Kokoro text-to-speech, through a public Hugging Face Space.
///
/// Device TTS was robotic, had no usable Hindi voice on most phones, and the
/// recorded clips could not keep up with the screens. Kokoro sounds like a
/// person in both languages.
///
/// Every sentence is cached on the device, so after one warm walkthrough the
/// voice works with no network at all. One failure marks the Space unreachable
/// for the rest of the session — a voice that stalls thirty seconds on every
/// screen is worse than the fallback.
class KokoroTts {
  KokoroTts({
    http.Client? client,
    VoiceCache? cache,
    this.baseUrl = defaultBaseUrl,
    this.voice = femaleVoice,
    this.timeout = const Duration(seconds: 40),
  }) : _injected = client,
       _cache = cache ?? VoiceCache();

  static const defaultBaseUrl = 'https://leonelhs-kokoro-tts-hindi.hf.space';
  static const femaleVoice = 'hf_alpha';
  static const maleVoice = 'hm_omega';

  final String baseUrl;
  final String voice;

  /// A sleeping Space takes about thirty seconds to answer its first request.
  final Duration timeout;

  final VoiceCache _cache;

  // Never construct an external resource in a constructor: it breaks
  // flutter_test at load time. Build it the first time it is needed.
  final http.Client? _injected;
  http.Client? _lazy;
  http.Client get _http => _injected ?? (_lazy ??= http.Client());

  bool _unreachable = false;

  /// True once the Space has failed this session.
  bool get unreachable => _unreachable;

  VoiceCache get cache => _cache;

  static String cacheKey(String text, AppLanguage language, double speed) =>
      sha1
          .convert(utf8.encode('${language.code}|$speed|${text.trim()}'))
          .toString();

  /// WAV bytes for [text], from the cache or the Space. Null when neither can
  /// provide them.
  Future<Uint8List?> synthesize(
    String text,
    AppLanguage language, {
    double speed = 1.0,
  }) async {
    final key = cacheKey(text, language, speed);
    final cached = await _cache.read(key);
    if (cached != null) return cached;
    if (_unreachable) return null;

    try {
      final bytes = await _fetch(text, speed).timeout(timeout);
      if (bytes == null) {
        _unreachable = true;
        return null;
      }
      await _cache.write(key, bytes);
      return bytes;
    } catch (_) {
      _unreachable = true;
      return null;
    }
  }

  /// Warm the cache for a set of sentences, one after another.
  Future<void> warm(Iterable<String> sentences, AppLanguage language) async {
    for (final s in sentences) {
      if (_unreachable) return;
      await synthesize(s, language);
    }
  }

  Future<Uint8List?> _fetch(String text, double speed) async {
    final start = await _http.post(
      Uri.parse('$baseUrl/gradio_api/call/predict'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'data': [text, voice, speed],
      }),
    );
    if (start.statusCode != 200) return null;
    final eventId = (jsonDecode(start.body) as Map)['event_id'] as String?;
    if (eventId == null) return null;

    final stream = await _http.get(
      Uri.parse('$baseUrl/gradio_api/call/predict/$eventId'),
    );
    if (stream.statusCode != 200) return null;
    final url = audioUrlFromSse(stream.body);
    if (url == null) return null;

    final audio = await _http.get(Uri.parse(url));
    if (audio.statusCode != 200 || audio.bodyBytes.isEmpty) return null;
    return audio.bodyBytes;
  }

  /// Pull the audio URL out of a Gradio server-sent-events body.
  ///
  /// The body is a series of `event:` / `data:` pairs. The one that matters is
  /// `event: complete`, whose data is a JSON list whose first item is the file
  /// — either an object with a `url`, or a bare path.
  static String? audioUrlFromSse(String body, {String? baseUrl}) {
    String? event;
    for (final raw in const LineSplitter().convert(body)) {
      final line = raw.trim();
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:') && event == 'complete') {
        final data = jsonDecode(line.substring(5).trim());
        if (data is! List || data.isEmpty) return null;
        final first = data.first;
        if (first is Map && first['url'] is String) return first['url'];
        if (first is Map && first['path'] is String) {
          return '${baseUrl ?? defaultBaseUrl}/gradio_api/file=${first['path']}';
        }
        if (first is String) return first;
        return null;
      }
    }
    return null;
  }
}
