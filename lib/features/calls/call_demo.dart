import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_state.dart';
import '../../domain/dose_alarm.dart';
import '../caregiver/whatsapp_alerts.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import 'medicine_demo.dart';

/// Demo Medicine Call. Shows the due medicines as big pictures and pill
/// counts, then asks the laptop bay to send one WhatsApp and add one
/// notification. The Twilio token stays on that server.
Future<void> openCallDemo(
  BuildContext context, {
  http.Client? client,
  String? bayUrl,
  DateTime Function() clock = DateTime.now,
}) async {
  final state = AppScope.of(context);
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  if (!context.mounted) return;
  final now = clock();
  final target = DoseAlarm.demoTarget(
    medicines: store.active(),
    now: now,
    taken: (date, slot) => logs.logFor(date, slot) != null,
  );
  final medicines = DoseAlarm.demoMedicines(
    AlarmPayload(slot: target.slot, date: target.date, demo: true),
    store.active(),
  );
  final to =
      WhatsAppAlerts.normalise(state.prefs.alertPhone) ??
      WhatsAppAlerts.normalise(state.prefs.phoneNumber);

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MedicineDemoPage(
        medicines: medicines,
        to: to,
        bayUrl: bayUrl ?? const String.fromEnvironment('BAY_URL'),
        client: client,
      ),
    ),
  );
}
