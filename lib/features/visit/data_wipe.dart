import '../../domain/pharmacy_check.dart';
import '../sync/sync_queue.dart';
import 'media_store.dart';
import 'visit.dart';

/// Deletes raw capture once the structured prescription is saved.
///
/// Transcripts, audio, handwritten note text, and temporary OCR go.
/// A queued job that still needs its clip ([SyncJob.needsRawClip]) keeps
/// that file until the job is done or dropped. Caretaker notes are not raw
/// capture and are left untouched.
abstract final class DataWipe {
  static const _textKeys = [
    'transcript',
    'doctorWords',
    'chemistWords',
    'ocrText',
    'noteText',
    'handwritten',
  ];

  static const _clipKeys = [
    'audio',
    'audioPath',
    'doctorAudioPath',
    'chemistAudioPath',
    'photos',
    'voiceNotePath',
  ];

  static Future<void> apply({
    required Visit visit,
    required MediaStore media,
    SyncQueue? queue,
  }) async {
    final jobs = queue?.all() ?? const <SyncJob>[];
    final keep = <String>{
      for (final job in jobs)
        if (job.needsRawClip) ...clipPaths(job),
    };
    final dropped = await _stripPayloads(queue, jobs);
    final paths = <String>{
      ...dropped,
      ?visit.doctorAudioPath,
      ?visit.chemistAudioPath,
      for (final photo in visit.photos) photo.path,
      for (final answer in visit.pharmacyResolutions) ?answer.voiceNotePath,
    };
    for (final path in paths) {
      if (keep.contains(path)) continue;
      await media.deleteFile(path);
    }
    _clearVisit(visit, keep);
  }

  /// The job finished or was dropped: the clip is no longer needed.
  static Future<void> releaseClip(SyncJob job, MediaStore media) async {
    for (final path in clipPaths(job)) {
      await media.deleteFile(path);
    }
  }

  static Iterable<String> clipPaths(SyncJob job) sync* {
    for (final key in _clipKeys) {
      yield* _paths(job.payload[key]);
    }
  }

  static Iterable<String> _paths(Object? value) sync* {
    if (value is String && value.isNotEmpty) yield value;
    if (value is List) {
      for (final item in value) {
        if (item is String && item.isNotEmpty) yield item;
      }
    }
  }

  static Future<Set<String>> _stripPayloads(
    SyncQueue? queue,
    List<SyncJob> jobs,
  ) async {
    final dropped = <String>{};
    if (queue == null) return dropped;
    final updates = <SyncJob>[];
    for (final job in jobs) {
      final next = Map<String, Object?>.of(job.payload);
      var changed = false;
      for (final key in _textKeys) {
        if (next.remove(key) != null) changed = true;
      }
      if (!job.needsRawClip) {
        for (final key in _clipKeys) {
          final removed = next.remove(key);
          if (removed == null) continue;
          changed = true;
          dropped.addAll(_paths(removed));
        }
      }
      if (changed) updates.add(job.copyWith(payload: next));
    }
    for (final job in updates) {
      await queue.add(job);
    }
    return dropped;
  }

  static void _clearVisit(Visit visit, Set<String> keep) {
    visit.doctorWords = '';
    visit.chemistWords = '';
    if (!keep.contains(visit.doctorAudioPath)) visit.doctorAudioPath = null;
    if (!keep.contains(visit.chemistAudioPath)) visit.chemistAudioPath = null;
    visit.photos.removeWhere((photo) {
      photo.ocrText = null;
      return !keep.contains(photo.path);
    });
    for (var i = 0; i < visit.pharmacyResolutions.length; i++) {
      final answer = visit.pharmacyResolutions[i];
      final path = answer.voiceNotePath;
      if (path == null || keep.contains(path)) continue;
      visit.pharmacyResolutions[i] = PharmacyResolution(
        kind: answer.kind,
        medicineId: answer.medicineId,
        choice: answer.choice,
        explanation: answer.explanation,
        answeredBy: answer.answeredBy,
        answeredAt: answer.answeredAt,
      );
    }
  }
}
