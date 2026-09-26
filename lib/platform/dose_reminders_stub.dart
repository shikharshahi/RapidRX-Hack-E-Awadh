import '../domain/reminder_planner.dart';
import '../domain/sig.dart';
import 'dose_reminders.dart';

DoseReminders createDoseReminders() => _Unsupported();

class _Unsupported implements DoseReminders {
  @override
  Future<ReminderStatus> sync(List<PlannedReminder> plan) async =>
      ReminderStatus.unsupported;

  @override
  Future<void> cancelSlot(DoseSlot slot) async {}
}
