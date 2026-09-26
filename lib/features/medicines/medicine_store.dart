import 'dart:convert';

import '../../domain/scheduled_medicine.dart';
import '../records/secure_record_store.dart';

/// The approved medicines and the visits they came from.
///
/// The JSON shapes are unchanged. The bytes live in [SecureRecordStore],
/// not in plain preferences (ADR-63).
class MedicineStore {
  MedicineStore(this._box);

  final VaultBox _box;

  static const _medicines = MedicalKeys.medicines;
  static const _records = MedicalKeys.records;

  static Future<MedicineStore> load() async =>
      MedicineStore(await SecureRecordStore.open());

  List<ScheduledMedicine> medicines() =>
      _readList(_medicines, ScheduledMedicine.fromJson);

  List<ScheduledMedicine> active() =>
      medicines().where((m) => m.active).toList();

  List<PrescriptionRecord> records() =>
      _readList(_records, PrescriptionRecord.fromJson)
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  /// Add an approved visit. A medicine already on the schedule under the same
  /// id is replaced: the newer prescription is the one being followed.
  Future<void> approve({
    required String visitId,
    required List<ScheduledMedicine> approved,
    DateTime? at,
    List<String> evidence = const [],
    String? caretakerNote,
    String notePriority = 'low',
  }) async {
    final byId = {for (final m in medicines()) m.id: m};
    for (final m in approved) {
      byId[m.id] = m;
    }
    await _write(_medicines, [for (final m in byId.values) m.toJson()]);

    final records = _readList(_records, PrescriptionRecord.fromJson)
      ..removeWhere((r) => r.id == visitId)
      ..add(
        PrescriptionRecord(
          id: visitId,
          addedAt: at ?? DateTime.now(),
          medicineNames: [for (final m in approved) m.name],
          evidence: evidence,
          caretakerNote: caretakerNote,
          notePriority: notePriority,
        ),
      );
    await _write(_records, [for (final r in records) r.toJson()]);
  }

  /// Attach a reading that arrived after approval, for review.
  Future<void> attachOnlineReading(String visitId, String json) async {
    final records = [
      for (final r in _readList(_records, PrescriptionRecord.fromJson))
        r.id == visitId ? r.withOnlineReading(json) : r,
    ];
    await _write(_records, [for (final r in records) r.toJson()]);
  }

  Future<void> stop(String id) async {
    final all = [
      for (final m in medicines()) m.id == id ? m.copyWith(active: false) : m,
    ];
    await _write(_medicines, [for (final m in all) m.toJson()]);
  }

  List<T> _readList<T>(String key, T Function(Map<String, Object?>) parse) {
    final raw = _box.read(key);
    if (raw == null) return [];
    try {
      return [
        for (final item in jsonDecode(raw) as List)
          parse((item as Map).cast<String, Object?>()),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(String key, List<Object?> value) =>
      _box.write(key, jsonEncode(value));
}
