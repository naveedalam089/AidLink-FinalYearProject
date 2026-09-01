// Purpose: Patient screen for viewing nearby doctors and clinics on an interactive map.
// File: lib/views/patient/nearby_map_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/localization/app_text.dart';
import 'widgets/nearby_providers_map_card.dart';

class NearbyMapScreen extends StatelessWidget {
  const NearbyMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // --- Build nearby doctors map view ---
    String t(String english) => AppText.of(context, english);

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t('Nearby Doctors & Clinics'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        // --- Display interactive map with nearby providers ---
        child: NearbyProvidersMapCard(compact: false, showTitle: true),
      ),
    );
  }
}
