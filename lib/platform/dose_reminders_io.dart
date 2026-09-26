import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/reminder_planner.dart';
import '../domain/sig.dart';
import 'dose_reminders.dart';

DoseReminders createDoseReminders() =>
    Platform.isAndroid ? _AndroidReminders() : _Unsupported();

class _AndroidReminders implements DoseReminders {
  // Built on first use: the plugin talks to the platform.
  FlutterLocalNotificationsPlugin? _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'dose_reminders',
    'Dose reminders',
    channelDescription: 'When a dose is due, and once more 30 minutes later',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
  );

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    final plugin = _plugin ??= FlutterLocalNotificationsPlugin();
    if (!_ready) {
      tzdata.initializeTimeZones();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    }
    return plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async {
    try {
      final android = await _android();
      final allowed =
          await android?.requestNotificationsPermission() ??
          await android?.areNotificationsEnabled() ??
          false;
      if (!allowed) return ReminderStatus.denied;

      // Exact, because an inexact alarm can drift by hours, and a tablet due
      // with breakfast reminded at 2pm is the same as no reminder. If exact
      // alarms are refused, an inexact one is still far better than none.
      var exact = await android?.canScheduleExactNotifications() ?? false;
      if (!exact) {
        exact = await android?.requestExactAlarmsPermission() ?? false;
      }
      final mode = exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      final plugin = _plugin!;
      await plugin.cancelAll();
      for (final r in plan) {
        await plugin.zonedSchedule(
          id: r.id,
          // An absolute instant: correct whatever zone the phone is in.
          scheduledDate: tz.TZDateTime.from(r.at.toUtc(), tz.UTC),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: mode,
          title: r.title,
          body: r.body,
        );
      }
      return ReminderStatus.ready;
    } catch (_) {
      return ReminderStatus.unsupported;
    }
  }

  @override
  Future<void> cancelSlot(DoseSlot slot) async {
    if (_plugin == null) await _android();
    for (final nudge in [false, true]) {
      await _plugin!.cancel(id: ReminderPlanner.idFor(slot, nudge: nudge));
    }
  }
}

class _Unsupported implements DoseReminders {
  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async =>
      ReminderStatus.unsupported;

  @override
  Future<void> cancelSlot(DoseSlot slot) async {}
}
