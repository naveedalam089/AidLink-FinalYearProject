// Purpose: Patient screen for viewing prescription details with medicine information.
// File: lib/views/patient/pescription_detail_screen.dart

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';

class PrescriptionDetailScreen extends StatelessWidget {
  const PrescriptionDetailScreen({Key? key}) : super(key: key);

  // --- Format date as DD/MM/YYYY ---
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // --- Create info chip with icon and label ---
  Widget _infoChip(
    IconData icon,
    String label, {
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final bgColor = backgroundColor ?? Colors.white.withOpacity(0.16);
    final fgColor = foregroundColor ?? Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fgColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: fgColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- Build section card with title and content ---
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EEE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.heading3.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Build prescription detail display ---
    String t(String english) => AppText.of(context, english);

    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final String doctorName = (args['doctorName'] ?? 'Unknown').toString();
    final String patientName = (args['patientName'] ?? 'Patient').toString();
    final List<dynamic> medicines = args['medicines'] is List
        ? args['medicines'] as List<dynamic>
        : const [];
    final String diagnosis = (args['diagnosis'] ?? '').toString();
    final String advice = (args['advice'] ?? args['notes'] ?? '').toString();
    final String? followUpDateText = args['followUpDateText']?.toString();
    final dynamic rawDate = args['date'];
    final DateTime date = rawDate is DateTime
        ? rawDate
        : DateTime.tryParse(rawDate?.toString() ?? '') ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        title: Text(
          t('Prescription Details'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7FBF8), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryGreen, Color(0xFF1AA24A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctorName,
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${t('Prescription for')} $patientName',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.white.withOpacity(0.92),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _infoChip(Icons.calendar_today, _formatDate(date)),
                        if (followUpDateText != null &&
                            followUpDateText.isNotEmpty)
                          _infoChip(Icons.event_available, followUpDateText),
                        _infoChip(
                          Icons.local_pharmacy,
                          '${medicines.length} medicines',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionCard(
                title: t('Diagnosis'),
                child: Text(
                  diagnosis.isEmpty ? t('No diagnosis provided') : diagnosis,
                  style: AppTypography.bodyText.copyWith(height: 1.5),
                ),
              ),
              _sectionCard(
                title: t('Medicines'),
                child: medicines.isEmpty
                    ? Text(
                        t('No medicines listed.'),
                        style: AppTypography.bodyText.copyWith(
                          color: Colors.grey[700],
                        ),
                      )
                    : Column(
                        children: medicines.asMap().entries.map((entry) {
                          final med = entry.value as Map<String, dynamic>;
                          return Container(
                            margin: EdgeInsets.only(
                              bottom: entry.key == medicines.length - 1
                                  ? 0
                                  : 10,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F9F6),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2ECE4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (med['name'] ?? '').toString().isEmpty
                                      ? t('Unnamed medicine')
                                      : (med['name'] ?? '').toString(),
                                  style: AppTypography.bodyText.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 8,
                                  children: [
                                    _infoChip(
                                      Icons.medication_outlined,
                                      'Dosage: ${(med['dosage'] ?? '').toString().isEmpty ? '-' : med['dosage']}',
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1F2A23),
                                    ),
                                    _infoChip(
                                      Icons.schedule,
                                      'Freq: ${(med['frequency'] ?? '').toString().isEmpty ? '-' : med['frequency']}',
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1F2A23),
                                    ),
                                    _infoChip(
                                      Icons.timelapse,
                                      'Duration: ${(med['duration'] ?? '').toString().isEmpty ? '-' : med['duration']}',
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF1F2A23),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              _sectionCard(
                title: t('Doctor Advice'),
                child: Text(
                  advice.isEmpty ? t('No advice') : advice,
                  style: AppTypography.bodyText.copyWith(height: 1.5),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: Text(
                    t('Close'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
