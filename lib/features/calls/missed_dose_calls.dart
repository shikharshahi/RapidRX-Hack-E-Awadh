import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/strings_calls.dart';
import '../../core/plain_language.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../caregiver/caregiver_notifier.dart';
import '../caregiver/whatsapp_alerts.dart';
import '../doses/dose_log_store.dart';
import 'call_gateway.dart';
import 'call_policy.dart';

/// A digit the gather webhook returned. 1 logs taken, 2 leaves the dose due,
/// 9 tells the caretaker, and silence logs nothing.
Future<CallDigit> applyReportedDigit({
  required String? digit,
  required DoseLogStore logs,
  required CaregiverNotifier alerts,
  required String patientName,
  required AppStrings strings,
  required DateTime date,
  required DoseSlot slot,
  required List<String> medicineIds,
  required DateTime at,
}) => applyCallDigit(
  digit: digit,
  logs: logs,
  date: date,
  slot: slot,
  medicineIds: medicineIds,
  at: at,
  tellFamily: () async {
    await alerts.callAlert(
      slot,
      date,
      strings.callHelp(patientName, PlainLanguage.slot(slot, strings)),
      kind: 'help',
    );
  },
);

/// Remembers, per slot per day, the first ring, the retry, and the alert.
class CallLedger {
  CallLedger(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'rapidrx.calls';

  SlotCallRecord read(DateTime date, DoseSlot slot) =>
      _all()[callDedupeKey(date, slot)] ?? SlotCallRecord.empty;

  Future<void> markFirst(DateTime date, DoseSlot slot, DateTime at) =>
      _save(date, slot, SlotCallRecord(firstAt: at));

  Future<void> markRetry(DateTime date, DoseSlot slot, DateTime at) {
    final current = read(date, slot);
    return _save(date, slot, current.copyWith(retryAt: at));
  }

  Future<void> markAlerted(DateTime date, DoseSlot slot) {
    final current = read(date, slot);
    return _save(date, slot, current.copyWith(alerted: true));
  }

  Map<String, SlotCallRecord> _all() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = (jsonDecode(raw) as Map).cast<String, Object?>();
      return {
        for (final e in decoded.entries)
          e.key: _decode(e.value as Map<String, Object?>),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _save(
    DateTime date,
    DoseSlot slot,
    SlotCallRecord record,
  ) async {
    final all = {..._all(), callDedupeKey(date, slot): record};
    await _prefs.setString(
      _key,
      jsonEncode({for (final e in all.entries) e.key: _encode(e.value)}),
    );
  }

  static Map<String, Object?> _encode(SlotCallRecord r) => {
    'first': r.firstAt?.toIso8601String(),
    'retry': r.retryAt?.toIso8601String(),
    'alerted': r.alerted,
  };

  static SlotCallRecord _decode(Map<String, Object?> j) => SlotCallRecord(
    firstAt: j['first'] == null ? null : DateTime.parse(j['first']! as String),
    retryAt: j['retry'] == null ? null : DateTime.parse(j['retry']! as String),
    alerted: j['alerted'] == true,
  );
}

/// After the missed window: one call, one retry, then the caretaker.
class MissedDoseCaller {
  MissedDoseCaller({
    required this.gateway,
    required this.ledger,
    required this.alerts,
    required this.patientName,
    required this.strings,
  });

  final CallGateway gateway;
  final CallLedger ledger;
  final CaregiverNotifier alerts;
  final String patientName;
  final AppStrings strings;

  Future<void> check({
    required Iterable<ScheduledMedicine> medicines,
    required DoseLogStore logs,
    required DateTime now,
    required String? phone,
    required AppLanguage language,
  }) async {
    for (final date in [now.subtract(const Duration(days: 1)), now]) {
      for (final slot in logs.missedOn(now, date, medicines)) {
        final due = ScheduleEngine.dueOn(medicines, date)[slot] ?? const [];
        await _one(
          date: date,
          slot: slot,
          now: now,
          phone: phone,
          language: language,
          names: [for (final m in due) m.name],
          taken: logs.logFor(date, slot) != null,
        );
      }
    }
  }

  Future<void> _one({
    required DateTime date,
    required DoseSlot slot,
    required DateTime now,
    required String? phone,
    required AppLanguage language,
    required List<String> names,
    required bool taken,
  }) async {
    final decision = CallPolicy.onUnanswered(
      record: ledger.read(date, slot),
      now: now,
      taken: taken,
    );
    if (decision.placeCall) {
      final to = WhatsAppAlerts.normalise(phone);
      if (!gateway.configured || to == null || names.isEmpty) return;
      final result = await gateway.requestCall(
        CallRequest(
          to: to,
          language: language,
          medicineNames: names,
          slot: slot,
          day: dayOf(date),
        ),
      );
      if (!result.accepted) return;
      if (decision.retry) {
        await ledger.markRetry(date, slot, decision.at!);
      } else {
        await ledger.markFirst(date, slot, decision.at!);
      }
      return;
    }
    if (!decision.alertCaretaker) return;
    final slotName = PlainLanguage.slot(slot, strings);
    final result = await alerts.callAlert(
      slot,
      date,
      strings.callUnanswered(patientName, slotName),
      kind: 'call',
    );
    if (result == NotifyResult.sent ||
        result == NotifyResult.queued ||
        result == NotifyResult.alreadySent) {
      await ledger.markAlerted(date, slot);
    }
  }
}
