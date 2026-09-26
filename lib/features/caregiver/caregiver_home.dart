import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/l10n/l10n.dart';
import '../../core/plain_language.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/app_bar_actions.dart';
import '../../core/widgets/rx_logo.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/scheduled_medicine.dart';
import '../../domain/sig.dart';
import '../doses/dose_log_store.dart';
import '../medicines/medicine_store.dart';
import 'family.dart';
import 'plan_summary.dart';
import 'whatsapp_alerts.dart';

/// The caregiver's half: today at a glance, the family number, and the plan in
/// plain words — sendable to anyone, installable by no one.
class CaregiverHome extends StatefulWidget {
  const CaregiverHome({
    super.key,
    required this.onRestart,
    this.store,
    this.logs,
    this.alerts,
    this.clock = DateTime.now,
  });

  final VoidCallback onRestart;
  final MedicineStore? store;
  final DoseLogStore? logs;
  final WhatsAppAlerts? alerts;
  final DateTime Function() clock;

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _CaregiverHomeState extends State<CaregiverHome> {
  MedicineStore? _store;
  DoseLogStore? _logs;
  late final WhatsAppAlerts _alerts = widget.alerts ?? WhatsAppAlerts();

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _logs = widget.logs;
    if (_store == null || _logs == null) _load();
  }

  Future<void> _load() async {
    final store = await MedicineStore.load();
    final logs = await DoseLogStore.load();
    if (mounted) {
      setState(() {
        _store = store;
        _logs = logs;
      });
    }
  }

  List<ScheduledMedicine> get _meds => _store?.active() ?? const [];

  Future<void> _changeNumber() async {
    final state = AppScope.of(context);
    final s = L10n.of(context);
    final ctl = TextEditingController(text: state.prefs.backupPhone ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s.familyNumberTitle),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          style: const TextStyle(fontSize: 22),
          decoration: const InputDecoration(prefixText: '+91 '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.pop(d, ctl.text),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final number = WhatsAppAlerts.normalise(value);
    if (number == null) {
      _say(s.familyNumberInvalid);
      return;
    }
    // Stored as ten digits, like the onboarding field.
    await state.prefs.setBackupPhone(number.substring(3));
    setState(() {});
  }

  Future<void> _sendStatus() async {
    final state = AppScope.of(context);
    final s = L10n.of(context);
    final to = WhatsAppAlerts.normalise(state.prefs.backupPhone);
    if (to == null) {
      _say(s.addFamilyFirst);
      return;
    }
    final body = PlanSummary.status(
      name: state.prefs.name ?? '',
      medicines: _meds,
      logs: _logs!,
      now: widget.clock(),
      s: s,
    );
    final result = await _alerts.send(to, body);
    if (!mounted) return;
    _say(switch (result) {
      AlertDelivery.sentAutomatically => s.sentAutomatically,
      AlertDelivery.openedInWhatsApp => s.openedInWhatsApp,
      AlertDelivery.failed => s.sendFailed,
    });
  }

  void _say(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final state = AppScope.of(context);
    final phone = state.prefs.backupPhone;
    final now = widget.clock();
    final due = _logs == null
        ? const <DoseSlot, List<ScheduledMedicine>>{}
        : ScheduleEngine.dueOn(_meds, now);

    return VoicePrompt(
      text: '${s.todaysDoses}. ${s.alertsWhy}',
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              const RxLogo(size: 32),
              const SizedBox(width: 12),
              Text(s.appName),
            ],
          ),
          actions: appBarActions(context, onRestart: widget.onRestart),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(s.todaysDoses, style: text.titleLarge),
            const SizedBox(height: 10),
            if (_meds.isEmpty)
              _Muted(s.noPrescriptionsYet)
            else
              Row(
                children: [
                  for (final (i, e) in due.entries.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _SlotPill(
                        label: PlainLanguage.slot(e.key, s),
                        status: _logs!.statusOf(now, now, e.key),
                      ),
                    ),
                  ],
                ],
              ),
            if (due.isEmpty && _meds.isNotEmpty) _Muted(s.nothingDueToday),
            const SizedBox(height: 22),
            Text(s.alerts, style: text.titleLarge),
            Text(s.alertsWhy, style: text.labelMedium?.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            _NumberRow(
              phone: phone,
              emptyText: s.noFamilyYet,
              changeLabel: s.change,
              onChange: _changeNumber,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.chat_rounded),
              label: Text(s.sendStatus),
              onPressed: _logs == null ? null : _sendStatus,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(s.sharePlan),
              onPressed: () => sharePlan(context, _meds),
            ),
            const SizedBox(height: 26),
            Text(s.medicineSchedule, style: text.titleLarge),
            const SizedBox(height: 8),
            if (_meds.isEmpty)
              _Muted(s.noPrescriptionsYet)
            else
              for (final m in _meds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Muted('• ${PlanSummary.sentence(m, now, s)}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: AppColors.muted),
  );
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.label, required this.status});

  final String label;
  final DoseStatus status;

  @override
  Widget build(BuildContext context) {
    final (fill, border, icon, color) = switch (status) {
      DoseStatus.taken => (
        AppColors.greenSoft,
        AppColors.green,
        Icons.check_circle_rounded,
        AppColors.green,
      ),
      DoseStatus.missed => (
        AppColors.redSoft,
        AppColors.red,
        Icons.error_rounded,
        AppColors.red,
      ),
      DoseStatus.dueNow => (
        AppColors.amberSoft,
        AppColors.amberDark,
        Icons.notifications_active_rounded,
        AppColors.amberDark,
      ),
      DoseStatus.notYet => (
        AppColors.surface,
        AppColors.hairline,
        Icons.schedule_rounded,
        AppColors.muted,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppTheme.radius * .8),
        border: Border.all(color: border, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.phone,
    required this.emptyText,
    required this.changeLabel,
    required this.onChange,
  });

  final String? phone;
  final String emptyText;
  final String changeLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final set = phone != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      decoration: BoxDecoration(
        color: set ? AppColors.greenSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: set ? AppColors.green : AppColors.hairline,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            set ? Icons.person_rounded : Icons.person_add_alt_outlined,
            color: set ? AppColors.green : AppColors.muted,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              set ? '+91 $phone' : emptyText,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            onPressed: onChange,
            child: Text(changeLabel),
          ),
        ],
      ),
    );
  }
}
