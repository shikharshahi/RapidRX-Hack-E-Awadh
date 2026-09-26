import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/l10n/strings_calls.dart';
import '../../domain/dose_alarm.dart';
import '../caregiver/whatsapp_alerts.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import 'call_gateway.dart';

/// Demo tools only. Confirms, then asks the gateway. An empty function URL
/// shows that calls are not configured and does not pretend one went out.
Future<void> openCallDemo(
  BuildContext context, {
  CallGateway? gateway,
  DateTime Function() clock = DateTime.now,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final state = AppScope.of(context);
  final s = L10n.of(context);
  final calls = gateway ?? HttpCallGateway();

  void say(String text) {
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  if (!calls.configured) {
    say(s.callNotConfigured);
    return;
  }

  final phone = WhatsAppAlerts.normalise(state.prefs.phoneNumber);
  if (phone == null) {
    say(s.callNoPhone);
    return;
  }

  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  if (!context.mounted) return;
  final now = clock();
  final target = DoseAlarm.demoTarget(
    medicines: store.active(),
    now: now,
    taken: (date, slot) => logs.logFor(date, slot) != null,
  );
  final names = [
    for (final m in DoseAlarm.medicinesFor(
      AlarmPayload(slot: target.slot, date: target.date),
      store.active(),
    ))
      m.name,
  ];
  if (names.isEmpty) {
    say(s.callNoDose);
    return;
  }

  final yes = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(s.callDemo),
      content: Text(s.callDemoConfirm(phone, names.join(', '))),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(s.confirm),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;

  final result = await calls.requestCall(
    CallRequest(
      to: phone,
      language: state.language,
      medicineNames: names,
      slot: target.slot,
      day: target.date,
    ),
  );
  if (!context.mounted) return;
  say(switch (result.status) {
    CallRequestStatus.notConfigured => s.callNotConfigured,
    CallRequestStatus.accepted => s.callRequested,
    CallRequestStatus.failed => s.callFailed,
  });
}
