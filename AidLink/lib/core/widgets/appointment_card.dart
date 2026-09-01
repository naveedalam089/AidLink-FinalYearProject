// Purpose: Reusable appointment display card widget.
// File: lib/core/widgets/appointment_card.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';
import '../constants/app_values.dart';

class AppointmentCard extends StatelessWidget {
  final String doctorName;
  final String date;
  final String time;
  final String status;
  final bool showAction;
  final VoidCallback? onTap;

  const AppointmentCard({
    Key? key,
    required this.doctorName,
    required this.date,
    required this.time,
    required this.status,
    this.showAction = false,
    this.onTap,
  }) : super(key: key);

  // --- Helper: Map appointment status to display color ---
  Color _getStatusColor() {
    switch (status) {
      case AppointmentStatus.approved:
      case "Confirmed":
        return AppColors.primaryGreen;
      case AppointmentStatus.pending:
      case "Pending":
        return Colors.orange;
      case AppointmentStatus.cancelled:
      case AppointmentStatus.cancelledLate:
      case AppointmentStatus.noShow:
      case "Cancelled":
        return Colors.red;
      case AppointmentStatus.completed:
        return Colors.green;
      case AppointmentStatus.rejected:
        return Colors.redAccent;
      default:
        return AppColors.borderGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Build appointment card with doctor, date/time, and status ---
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
          // Display doctor name, date/time, status indicator
          children: [
            Text(doctorName, style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Date: $date", style: AppTypography.bodyText),
                Text("Time: $time", style: AppTypography.bodyText),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _getStatusColor(),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  status,
                  style: AppTypography.bodyText.copyWith(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (showAction && onTap != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
