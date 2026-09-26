import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Camera and gallery. Built lazily: the picker touches a platform channel.
class PhotoCapture {
  PhotoCapture({ImagePicker? picker}) : _injected = picker;

  final ImagePicker? _injected;
  ImagePicker? _lazy;
  ImagePicker get _picker => _injected ?? (_lazy ??= ImagePicker());

  Future<XFile?> camera() => _pick(ImageSource.camera);

  Future<XFile?> gallery() => _pick(ImageSource.gallery);

  Future<List<XFile>> galleryMany() async {
    try {
      return await _picker.pickMultiImage(imageQuality: 88, maxWidth: 2400);
    } catch (_) {
      return const [];
    }
  }

  Future<XFile?> _pick(ImageSource source) async {
    try {
      return await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2400,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Doctor and chemist audio. Off by default in the wizard — the words matter
/// more than the recording — but kept when the user asks.
class AudioCapture {
  AudioRecorder? _lazy;
  AudioRecorder get _recorder => _lazy ??= AudioRecorder();

  bool _recording = false;
  bool get recording => _recording;

  /// Starts recording. Returns false when there is no microphone or no
  /// permission, so the screen can say so rather than pretend.
  Future<bool> start() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/'
                'rx_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      _recording = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops and returns the recording, or null if nothing was captured.
  Future<XFile?> stop() async {
    if (!_recording) return null;
    _recording = false;
    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) return null;
      return XFile(path, name: 'audio.m4a', mimeType: 'audio/mp4');
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    if (_lazy == null) return;
    try {
      await _recorder.dispose();
    } catch (_) {}
  }
}
