import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/voice/voice_prompt.dart';
import '../../core/widgets/app_bar_actions.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../ai/ai_config.dart';
import '../../ai/gemini_client.dart';
import '../../core/app_state.dart';
import '../caregiver/family.dart';
import '../doses/dose_log_store.dart';
import '../doses/schedule_screen.dart';
import '../medicines/medicine_store.dart';
import '../visit/visit.dart';
import '../visit/visit_repository.dart';
import '../wizard/online_read_card.dart';
import '../wizard/wizard_controller.dart';
import '../wizard/wizard_screen.dart';
import 'prescriptions_screen.dart';

/// Where the patient lands: three things they can do, all visible at once.
///
/// A menu, not today's doses (ADR-19). The first thing a new user needs is to
/// add a prescription, and the first thing a returning user needs depends on
/// the time of day — so the app asks rather than guessing.
class PatientMenu extends StatelessWidget {
  const PatientMenu({
    super.key,
    required this.onRestart,
    this.onNewPrescription,
    this.onSchedule,
  });

  final VoidCallback onRestart;
  final VoidCallback? onNewPrescription;
  final VoidCallback? onSchedule;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    final tiles = <Widget>[
      _MenuTile(
        icon: Icons.add_a_photo_outlined,
        title: s.newPrescription,
        subtitle: s.newPrescriptionWhy,
        onTap: onNewPrescription ?? () => openWizard(context),
      ),
      _MenuTile(
        icon: Icons.description_outlined,
        title: s.myPrescriptions,
        subtitle: s.myPrescriptionsWhy,
        onTap: () => openPrescriptions(context),
      ),
      _MenuTile(
        icon: Icons.schedule_rounded,
        title: s.medicineSchedule,
        subtitle: s.medicineScheduleWhy,
        onTap: onSchedule ?? () => openSchedule(context),
      ),
    ];

    return VoicePrompt(
      text:
          '${s.menuQuestion} 1. ${s.newPrescription}. '
          '2. ${s.myPrescriptions}. 3. ${s.medicineSchedule}.',
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.menuTitle),
          actions: appBarActions(context, onRestart: onRestart),
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // All three tiles must fit without scrolling. Below this height
                // they would squash their text, so scroll instead.
                const minTile = 150.0;
                const header = 56.0;
                final fits =
                    (constraints.maxHeight - header - 32) / 3 >= minTile;
                final heading = Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    s.menuQuestion,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                );
                if (!fits) {
                  return ListView(
                    children: [
                      heading,
                      for (final t in tiles)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SizedBox(height: minTile, child: t),
                        ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> openPrescriptions(BuildContext context) async {
  final navigator = Navigator.of(context);
  final store = await MedicineStore.load();
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PrescriptionsScreen(records: store.records()),
    ),
  );
}

Future<void> openSchedule(BuildContext context) async {
  final navigator = Navigator.of(context);
  final state = AppScope.of(context);
  final store = await MedicineStore.load();
  final logs = await DoseLogStore.load();
  final family = familyNotifier(state);
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (routeContext) => ScheduleScreen(
        store: store,
        logs: logs,
        // Nothing runs in the background, so opening the schedule is when
        // missed doses are found and queued alerts get another go.
        onOpened: (meds, now) async {
          await family.drainOutbox(now: now);
          await family.checkMissed(meds, logs, now: now);
        },
        onConfirmed: (slot, date) =>
            family.doseTaken(slot, date, now: DateTime.now()),
        onShare: () => sharePlan(routeContext, store.active()),
      ),
    ),
  );
}

/// Start (or resume) a new prescription. A visit left half-way is picked up
/// where it was, because it was saved after every capture.
Future<void> openWizard(BuildContext context) async {
  final navigator = Navigator.of(context);
  final repository = await VisitRepository.load();
  final store = await MedicineStore.load();
  // One client per visit: its budget of calls is per visit.
  final gemini = GeminiClient();
  final controller = VisitWizardController(
    visit: repository.loadDraft() ?? Visit.start(),
    repository: repository,
    store: store,
  );
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => WizardScreen(
        controller: controller,
        // Only with a key. The card also hides itself when offline.
        onlineCard: AiConfig.hasGeminiKey
            ? (c) => OnlineReadCard(controller: c, client: gemini)
            : null,
      ),
    ),
  );
  controller.dispose();
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BigChoiceTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      iconSize: 60,
      titleStyle: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontSize: 24, height: 1.2),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      alignTop: true,
      minHeight: AppTheme.tapTarget,
    );
  }
}
