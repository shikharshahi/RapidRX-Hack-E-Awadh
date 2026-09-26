import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/big_choice_tile.dart';
import '../../core/widgets/rx_logo.dart';

enum AppRole { patient, caregiver }

/// Who is using this app?
///
/// Two tiles and nothing else. The answer decides which half of the product
/// this phone becomes, so it gets a whole screen to itself.
class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key, required this.onChosen});

  final ValueChanged<AppRole> onChosen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: AppTheme.pagePadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppTheme.pagePadding.vertical,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: RxWordmark(tagline: 'Every dose, on time'),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Who is using this app?',
                    textAlign: TextAlign.center,
                    style: text.headlineLarge?.copyWith(fontSize: 32),
                  ),
                  const SizedBox(height: 20),
                  BigChoiceTile(
                    icon: Icons.elderly_rounded,
                    title: 'PATIENT',
                    subtitle: 'I want to track my prescription',
                    onTap: () => onChosen(AppRole.patient),
                  ),
                  const SizedBox(height: 18),
                  BigChoiceTile(
                    icon: Icons.volunteer_activism_rounded,
                    title: 'CAREGIVER',
                    subtitle:
                        'I want to help a patient track their prescription',
                    onTap: () => onChosen(AppRole.caregiver),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
