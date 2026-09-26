import 'dart:convert';

import '../records/secure_record_store.dart';
import 'visit.dart';

/// The in-progress visit, kept on the device between every capture.
///
/// The draft used to sit in shared_preferences. It is one field in
/// [SecureRecordStore] now.
class VisitRepository {
  VisitRepository(this._box);

  final VaultBox _box;

  static const _draft = MedicalKeys.visit;

  static Future<VisitRepository> load() async =>
      VisitRepository(await SecureRecordStore.open());

  Visit? loadDraft() {
    final raw = _box.read(_draft);
    if (raw == null) return null;
    try {
      return Visit.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      // A draft from an older build that no longer parses is not worth a
      // crash on launch. Start a fresh one.
      return null;
    }
  }

  Future<void> save(Visit visit) =>
      _box.write(_draft, jsonEncode(visit.toJson()));

  Future<void> clear() => _box.write(_draft, null);
}
