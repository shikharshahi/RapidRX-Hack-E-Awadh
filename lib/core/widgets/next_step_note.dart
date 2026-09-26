import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// An amber "what comes next" note, for a screen whose real content is not
/// built yet.
///
/// Remove it from every screen that is now real before the demo — a note that
/// promises a feature which already exists reads as unfinished.
class NextStepNote extends StatelessWidget {
  const NextStepNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppColors.amberBorder, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.construction_rounded,
              color: AppColors.amberDark, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
