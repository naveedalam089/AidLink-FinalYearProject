/// Doctor prescription history screen.
///
/// Shows a list of all prescriptions for a given patient (from any doctor).
/// The widget adapts to mobile (full-screen with AppBar) and web (embedded
/// without AppBar) by using the `showAppBar` flag. Each prescription is shown
/// as an expandable card: collapsed shows summary (doctor, specialization,
/// date, short diagnosis) and expanding reveals full diagnosis, medicines,
/// follow-up date and advice.
///
/// File: lib/views/doctor_mobile/patient_prescription_history_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/app_values.dart';

class PatientPrescriptionHistoryScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final bool showAppBar;

  const PatientPrescriptionHistoryScreen({
    Key? key,
    required this.patientId,
    required this.patientName,
    this.showAppBar = true,
  }) : super(key: key);

  /// Creates a prescription history screen for [patientId].
  ///
  /// [patientName] is used for display in the AppBar when [showAppBar] is true.
  /// Set [showAppBar] to false when embedding this widget inside another
  /// scrolling container (e.g. web dashboard) so the parent handles the
  /// navigation and scrolling.

  @override
  State<PatientPrescriptionHistoryScreen> createState() =>
      _PatientPrescriptionHistoryScreenState();
}

class _PatientPrescriptionHistoryScreenState
    extends State<PatientPrescriptionHistoryScreen> {
  // --- Parse medicines list from Firestore data ---
  List<Map<String, String>> _parseMedicines(dynamic rawMedicines) {
    if (rawMedicines is! List) return const [];

    return rawMedicines.map<Map<String, String>>((item) {
      if (item is Map<String, dynamic>) {
        return {
          'name': (item['name'] ?? '').toString(),
          'dosage': (item['dosage'] ?? '').toString(),
          'frequency': (item['frequency'] ?? '').toString(),
          'duration': (item['duration'] ?? '').toString(),
        };
      }
      return {
        'name': item.toString(),
        'dosage': '',
        'frequency': '',
        'duration': '',
      };
    }).toList();
  }

  // --- Format date as DD/MM/YYYY ---
  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  // --- Fetch doctor information ---
  Future<Map<String, dynamic>> _loadDoctorData(String doctorId) async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(doctorId)
        .get();
    return snap.data() ?? <String, dynamic>{};
  }

  // --- Format doctor name ---
  String _doctorNameFromData(Map<String, dynamic> doctor) {
    final first = (doctor['firstName'] ?? '').toString().trim();
    final last = (doctor['lastName'] ?? '').toString().trim();
    final full = [
      first,
      last,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    return full.isEmpty ? 'Doctor' : 'Dr. $full';
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _buildContent();

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primaryGreen,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            '${widget.patientName} - Medical History',
            style: AppTypography.heading3.copyWith(color: Colors.white),
          ),
        ),
        body: bodyContent,
      );
    }

    return bodyContent;
  }

  Widget _buildContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.prescriptions)
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Unable to load prescriptions\nPatient ID: ${widget.patientId}\nError: ${snapshot.error}',
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data!.docs;
        if (prescriptions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_information_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No prescriptions available',
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          itemCount: prescriptions.length,
          shrinkWrap: !widget.showAppBar,
          physics: widget.showAppBar
              ? const AlwaysScrollableScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final doc = prescriptions[index];
            final data = doc.data() as Map<String, dynamic>;

            final doctorId = (data['doctorId'] ?? '').toString();
            final medicines = _parseMedicines(data['medicines']);
            final diagnosis = (data['diagnosis'] ?? '').toString();
            final advice =
                (data[PrescriptionFields.advice] ?? data['notes'] ?? '')
                    .toString();

            final followUp = data['followUpDate'];
            String? followUpDateText;
            if (followUp is Timestamp) {
              followUpDateText = _formatDate(followUp.toDate());
            }

            final createdAt = data['createdAt'];
            final DateTime date = createdAt is Timestamp
                ? createdAt.toDate()
                : DateTime.now();

            return FutureBuilder<Map<String, dynamic>>(
              future: _loadDoctorData(doctorId),
              builder: (context, doctorSnap) {
                if (doctorSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }

                final doctorData = doctorSnap.data ?? <String, dynamic>{};
                final doctorName = _doctorNameFromData(doctorData);
                final doctorSpecialization =
                    (doctorData['specialization'] ?? 'General')
                        .toString()
                        .trim();

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                    horizontal: 0,
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: AppTypography.heading3.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctorSpecialization,
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              _formatDate(date),
                              style: AppTypography.bodyText.copyWith(
                                fontSize: 11,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (diagnosis.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                diagnosis.length > 35
                                    ? '${diagnosis.substring(0, 35)}...'
                                    : diagnosis,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(height: 1),

                            // --- Full Diagnosis ---
                            if (diagnosis.isNotEmpty) ...[
                              Text(
                                'Diagnosis',
                                style: AppTypography.heading3.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  diagnosis,
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            // --- Medicines ---
                            if (medicines.isNotEmpty) ...[
                              Text(
                                'Medicines',
                                style: AppTypography.heading3.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: medicines.map((medicine) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.borderGray,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            medicine['name'] ?? '',
                                            style: AppTypography.bodyText
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Dosage: ${medicine['dosage'] ?? 'N/A'}',
                                                  style: AppTypography.bodyText
                                                      .copyWith(
                                                        fontSize: 12,
                                                        color: Colors.grey[700],
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Frequency: ${medicine['frequency'] ?? 'N/A'}',
                                                  style: AppTypography.bodyText
                                                      .copyWith(
                                                        fontSize: 12,
                                                        color: Colors.grey[700],
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Duration: ${medicine['duration'] ?? 'N/A'}',
                                            style: AppTypography.bodyText
                                                .copyWith(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],

                            // --- Follow-up & Advice ---
                            if (followUpDateText != null ||
                                advice.isNotEmpty) ...[
                              Row(
                                children: [
                                  if (followUpDateText != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Follow-up',
                                            style: AppTypography.bodyText
                                                .copyWith(fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            followUpDateText,
                                            style: AppTypography.bodyText
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.primaryGreen,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              if (advice.isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Advice',
                                  style: AppTypography.heading3.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                    ),
                                  ),
                                  child: Text(
                                    advice,
                                    style: AppTypography.bodyText.copyWith(
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
