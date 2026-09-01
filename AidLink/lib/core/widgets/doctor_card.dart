import 'dart:convert';

// Purpose: Reusable doctor profile card widget for listing and selection.
// File: lib/core/widgets/doctor_card.dart

import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../constants/spacing.dart';

class DoctorCard extends StatelessWidget {
  final String name;
  final String specialization;
  final String? imageUrl; // Nullable for flexibility

  const DoctorCard({
    Key? key,
    required this.name,
    required this.specialization,
    this.imageUrl,
  }) : super(key: key);

  // --- Helper: Resolve image from base64, network, or asset ---
  ImageProvider _profileImageProvider(String? rawValue) {
    final value = (rawValue ?? '').toString().trim();

    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(value.split(',').last));
      } catch (_) {
        return const AssetImage('assets/images/default_profile.jpg');
      }
    }

    if (value.isNotEmpty) {
      return NetworkImage(value);
    }

    return const AssetImage('assets/images/default_profile.jpg');
  }

  @override
  Widget build(BuildContext context) {
    // --- Build card with doctor profile info ---
    return Card(
      color: AppColors.backgroundWhite, // ✅ Matches app background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryGreen), // ✅ Brand color border
      ),
      elevation: 2, // ✅ Slight shadow for clean look
      // Card content: avatar + doctor info
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: _profileImageProvider(imageUrl),
            ),
            SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.primaryGreen, // ✅ Brand color for name
                  ),
                ),
                Text(
                  specialization,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey, // ✅ Subtle secondary text
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
