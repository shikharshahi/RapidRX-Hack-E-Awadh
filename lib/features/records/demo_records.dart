import 'dart:convert';

import '../../domain/dose_clock.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../../core/l10n/app_language.dart';
import '../../core/storage/app_prefs.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import '../pairing/patient_pairing.dart';
import 'secure_record_store.dart';

/// One demo patient, rebuilt from these constants every time.
///
/// The doses below are stated here. Nothing is read off a slip and nothing
/// is filled in because a field was empty.
abstract final class DemoRecords {
  static const name = 'Demo user';
  static const age = 72;
  static const phone = '9000000001';
  static const pin = '1357';
  static const caretakerName = 'Sunita';
  static const caretakerPhone = '9811111111';

  static const telmaId = 'demo-telma-40';
  static const glycometId = 'demo-glycomet-500';

  static DemoPlan plan(DateTime now) {
    final today = dayOf(now);
    final past = <DoseSlot>[];
    final later = <DoseSlot>[];
    for (final slot in DoseSlot.values) {
      if (now.isBefore(DoseClock.missedAt(today, slot))) {
        later.add(slot);
      } else {
        past.add(slot);
      }
    }
    // One missed slot when any slot is already missed; earlier ones are
    // taken. A future slot is never marked taken.
    final taken = past.length <= 1
        ? const <DoseSlot>[]
        : past.sublist(0, past.length - 1);
    return DemoPlan(
      today: today,
      takenToday: taken,
      missedToday: past.isEmpty ? null : past.last,
      upcomingToday: later,
    );
  }

  static List<DoseLog> week(DateTime now) {
    final today = dayOf(now);
    final takenToday = plan(now).takenToday.toSet();
    final logs = <DoseLog>[];
    for (var ago = 6; ago >= 0; ago--) {
      final day = today.subtract(Duration(days: ago));
      for (final slot in DoseSlot.values) {
        final todaySlot = ago == 0;
        if (todaySlot && !takenToday.contains(slot)) continue;
        logs.add(
          DoseLog(
            date: day,
            slot: slot,
            confirmedAt: DoseClock.dueAt(day, slot),
            taken: _ids(slot),
          ),
        );
      }
    }
    return logs;
  }

  static DemoPreview preview(DateTime now) => DemoPreview(
    date: _date(dayOf(now)),
    medicines: 2,
    prescriptions: 2,
    doses: week(now).length,
  );

  /// Replace whatever is in [store] with this fixture. Caller decides whether
  /// the backup mirror stays off (a real file must be left alone).
  static Future<void> install({
    required AppPrefs prefs,
    required SecureRecordStore store,
    required DateTime Function() clock,
  }) async {
    final now = clock();
    final today = dayOf(now);
    final start = today.subtract(const Duration(days: 6));
    for (final key in MedicalKeys.all) {
      await store.write(key, null);
    }
    await prefs.setLanguage(AppLanguage.en);
    await prefs.setVoiceHelp(false);
    await prefs.setPhoneNumber(phone);
    await prefs.setName(name);
    await prefs.setRole(AppRole.patient);
    await prefs.setHealth(age: age);
    await prefs.setLinkedCaretakerJson(
      jsonEncode(
        LinkedCaretaker(
          id: 'demo-sunita',
          name: caretakerName,
          phone: caretakerPhone,
          type: CaretakerType.family,
          linkedAt: today,
        ).toJson(),
      ),
    );
    await prefs.setDemoUser(true);

    final telma = ScheduledMedicine(
      id: telmaId,
      name: 'TELMA 40',
      strength: '40',
      sig: const Sig(
        slots: [DoseSlot.morning, DoseSlot.night],
        food: FoodTiming.after,
        durationDays: 30,
      ),
      startDate: start,
    );
    final glycomet = ScheduledMedicine(
      id: glycometId,
      name: 'GLYCOMET 500',
      strength: '500',
      sig: const Sig(
        slots: [DoseSlot.afternoon, DoseSlot.evening],
        food: FoodTiming.after,
        durationDays: 30,
      ),
      startDate: start,
    );
    final medicines = MedicineStore(store);
    await medicines.approve(
      visitId: 'demo-rx-telma',
      approved: [telma],
      at: start,
      evidence: const ['doctor', 'bill'],
    );
    await medicines.approve(
      visitId: 'demo-rx-glycomet',
      approved: [glycomet],
      at: start.add(const Duration(days: 1)),
      evidence: const ['doctor', 'bill'],
    );
    final logs = DoseLogStore(store);
    for (final log in week(now)) {
      await logs.logTaken(
        date: log.date,
        slot: log.slot,
        medicineIds: log.taken,
        at: log.confirmedAt,
      );
    }
    await prefs.setPin(pin);
    await store.rewrap(pin);
  }

  static List<String> _ids(DoseSlot slot) => switch (slot) {
    DoseSlot.morning || DoseSlot.night => const [telmaId],
    DoseSlot.afternoon || DoseSlot.evening => const [glycometId],
  };

  static String _date(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$d';
  }
}

class DemoPlan {
  const DemoPlan({
    required this.today,
    required this.takenToday,
    required this.missedToday,
    required this.upcomingToday,
  });

  final DateTime today;
  final List<DoseSlot> takenToday;
  final DoseSlot? missedToday;
  final List<DoseSlot> upcomingToday;
}

class DemoPreview {
  const DemoPreview({
    required this.date,
    required this.medicines,
    required this.prescriptions,
    required this.doses,
  });

  final String date;
  final int medicines;
  final int prescriptions;
  final int doses;
}
