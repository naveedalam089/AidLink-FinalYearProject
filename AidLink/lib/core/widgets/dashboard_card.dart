// Purpose: Reusable metric/stat card widget for admin dashboard displays.
// File: lib/core/widgets/dashboard_card.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const DashboardCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Build metric card with icon, value, and title ---
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // --- Layout: icon, value, title vertically centered ---
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppColors.primaryGreen),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.heading2.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTypography.bodyText),
            ],
          ),
        ),
      ),
    );
  }
}
