import 'dart:async';

import 'package:flutter/widgets.dart';

import '../l10n/app_language.dart';
import 'kokoro_tts.dart';
import 'speech_engine.dart';

/// Reads screens aloud — and makes sure only the newest screen is talking.
///
/// Without an owner, a user who moves quickly hears the previous screen talking
/// over the new one. So speaking claims the voice with an owner token; a screen
/// stops the voice on its way out only if it still owns it; and a sentence that
/// finishes loading after its screen has gone is simply dropped.
class VoiceGuide extends ChangeNotifier {
  VoiceGuide({SpeechEngine? engine, this.enabled = false})
    : _engine =
          engine ??
          ChainEngine([KokoroEngine(tts: KokoroTts()), DeviceTtsEngine()]);

  final SpeechEngine _engine;

  bool enabled;

  Object? _speaker;

  /// Who holds the voice right now.
  Object? get speaker => _speaker;

  /// Speak [text] for [owner], replacing whatever was playing.
  Future<void> speak(Object owner, String text, AppLanguage language) async {
    if (!enabled || text.trim().isEmpty) return;
    final previous = _speaker;
    _speaker = owner;
    if (previous != null) await _engine.stop();
    // Another screen may have claimed the voice while we were stopping.
    if (!identical(_speaker, owner)) return;
    await _engine.speak(text, language);
  }

  /// Stop only if [owner] is the one speaking. A screen leaving must never
  /// silence the screen that replaced it.
  Future<void> stopIfSpeaking(Object owner) async {
    if (!identical(_speaker, owner)) return;
    _speaker = null;
    await _engine.stop();
  }

  Future<void> stopAll() async {
    _speaker = null;
    await _engine.stop();
  }
}

class VoiceScope extends InheritedWidget {
  const VoiceScope({super.key, required this.guide, required super.child});

  final VoiceGuide guide;

  static VoiceGuide? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<VoiceScope>()?.guide;

  @override
  bool updateShouldNotify(VoiceScope old) => old.guide != guide;
}
