import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';

/// What a family caretaker should see before the rest of the home:
/// misses, and prescriptions from the last week.
///
/// There is no stored "unverified" flag on an approved visit, so a new
/// prescription is one added inside [days]. A visit still in the wizard
/// is not on this list.
abstract final class FamilyBrief {
  static List<({DateTime day, DoseSlot slot})> missed({
    required DateTime now,
    required List<ScheduledMedicine> medicines,
    required DoseLogStore logs,
    int days = 7,
  }) {
    final today = dayOf(now);
    final out = <({DateTime day, DoseSlot slot})>[];
    for (var i = 0; i < days; i++) {
      final day = today.subtract(Duration(days: i));
      for (final slot in logs.missedOn(now, day, medicines)) {
        out.add((day: day, slot: slot));
      }
    }
    return out;
  }

  static List<PrescriptionRecord> recent(
    List<PrescriptionRecord> records,
    DateTime now, {
    int days = 7,
  }) {
    final cutoff = dayOf(now).subtract(Duration(days: days - 1));
    return [
      for (final r in records)
        if (!dayOf(r.addedAt).isBefore(cutoff)) r,
    ];
  }
}
