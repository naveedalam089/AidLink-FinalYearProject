// Purpose: Reusable patient information display card widget.
// File: lib/core/widgets/patient_info_card.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../constants/typography.dart';

class PatientInfoCard extends StatelessWidget {
  final String name;
  final int age;
  final String contact;
  final String history;

  const PatientInfoCard({
    Key? key,
    required this.name,
    required this.age,
    required this.contact,
    required this.history,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Build patient info card with name, age, contact, history ---
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Patient name, age, contact, history
          children: [
            Text(name, style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            Text('Age: $age', style: AppTypography.bodyText),
            Text('Contact: $contact', style: AppTypography.bodyText),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'History:',
              style: AppTypography.heading3.copyWith(fontSize: 16),
            ),
            Text(history, style: AppTypography.bodyText),
          ],
        ),
      ),
    );
  }
}
