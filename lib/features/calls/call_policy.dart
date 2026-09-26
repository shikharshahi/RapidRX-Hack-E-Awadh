import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';

/// One slot on one day. A second check of the same key must not place
/// another call.
String callDedupeKey(DateTime date, DoseSlot slot) {
  final d = dayOf(date);
  return '${d.year}-${d.month}-${d.day}/${slot.name}';
}

/// What this phone has already done about one slot.
class SlotCallRecord {
  const SlotCallRecord({this.firstAt, this.retryAt, this.alerted = false});

  static const empty = SlotCallRecord();

  final DateTime? firstAt;
  final DateTime? retryAt;
  final bool alerted;

  SlotCallRecord copyWith({
    DateTime? firstAt,
    DateTime? retryAt,
    bool? alerted,
  }) => SlotCallRecord(
    firstAt: firstAt ?? this.firstAt,
    retryAt: retryAt ?? this.retryAt,
    alerted: alerted ?? this.alerted,
  );
}

/// What to do about a dose that is still unanswered.
class CallDecision {
  const CallDecision._({
    required this.placeCall,
    required this.retry,
    required this.alertCaretaker,
    this.at,
  });

  const CallDecision.none()
    : this._(placeCall: false, retry: false, alertCaretaker: false);

  const CallDecision.place(DateTime at)
    : this._(placeCall: true, retry: false, alertCaretaker: false, at: at);

  const CallDecision.retry(DateTime at)
    : this._(placeCall: true, retry: true, alertCaretaker: false, at: at);

  const CallDecision.alert()
    : this._(placeCall: false, retry: false, alertCaretaker: true);

  /// Ask the function to ring the patient.
  final bool placeCall;

  /// This ring is the one retry, not the first call.
  final bool retry;

  /// Both rings went unanswered. Tell the caretaker. Do not ring again.
  final bool alertCaretaker;

  /// When the ring is due. For a retry this is the first call plus an hour,
  /// even if the app opens later than that.
  final DateTime? at;
}

/// Per slot: one call, one retry an hour later, then the caretaker.
/// Silence is not a dose.
abstract final class CallPolicy {
  static const retryAfter = Duration(minutes: 60);

  static CallDecision onUnanswered({
    required SlotCallRecord record,
    required DateTime now,
    required bool taken,
  }) {
    if (taken || record.alerted) return const CallDecision.none();
    final first = record.firstAt;
    if (first == null) return CallDecision.place(now);
    final retryAt = record.retryAt;
    if (retryAt == null) {
      final due = first.add(retryAfter);
      if (now.isBefore(due)) return const CallDecision.none();
      return CallDecision.retry(due);
    }
    // The retry has to have gone out before a later check can call it a miss.
    // The same instant must not alert and ring.
    if (!now.isAfter(retryAt)) return const CallDecision.none();
    return const CallDecision.alert();
  }
}

/// What a keypress means. Anything else, including no digit, changes nothing.
enum CallDigit { taken, later, family, ignore }

CallDigit interpretDigit(String? raw) {
  final digit = raw?.trim();
  return switch (digit) {
    '1' => CallDigit.taken,
    '2' => CallDigit.later,
    '9' => CallDigit.family,
    _ => CallDigit.ignore,
  };
}

/// 1 logs the slot taken. 2 leaves it due. 9 tells the family. A missing or
/// unknown digit logs nothing.
Future<CallDigit> applyCallDigit({
  required String? digit,
  required DoseLogStore logs,
  required DateTime date,
  required DoseSlot slot,
  required List<String> medicineIds,
  required DateTime at,
  Future<void> Function()? tellFamily,
}) async {
  final effect = interpretDigit(digit);
  switch (effect) {
    case CallDigit.taken:
      await logs.logTaken(
        date: date,
        slot: slot,
        medicineIds: medicineIds,
        at: at,
      );
    case CallDigit.later:
    case CallDigit.ignore:
      break;
    case CallDigit.family:
      if (tellFamily != null) await tellFamily();
  }
  return effect;
}
