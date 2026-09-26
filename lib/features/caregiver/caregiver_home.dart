import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bar_actions.dart';
import '../../core/widgets/next_step_note.dart';
import '../../core/widgets/rx_logo.dart';

/// The caregiver's half of the app.
class CaregiverHome extends StatelessWidget {
  const CaregiverHome({super.key, required this.onRestart});

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final s = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const RxLogo(size: 32),
            const SizedBox(width: 12),
            Text(s.appName),
          ],
        ),
        actions: appBarActions(context, onRestart: onRestart),
      ),
      body: ListView(
        padding: AppTheme.pagePadding,
        children: const [
          NextStepNote(
            text: 'Next: today\'s doses per slot, the family WhatsApp number, '
                'and the plan in plain words.',
          ),
        ],
      ),
    );
  }
}
