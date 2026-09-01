// Purpose: Patient screen for viewing their prescriptions (list, details, PDF export).
// File: lib/views/patient/my_prescriptions_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';
import '../../core/utils/pdf_file_save.dart';
import '../../core/utils/prescription_pdf_builder.dart';

class MyPrescriptionsScreen extends StatefulWidget {
  const MyPrescriptionsScreen({Key? key}) : super(key: key);

  @override
  State<MyPrescriptionsScreen> createState() => _MyPrescriptionsScreenState();
}

class _MyPrescriptionsScreenState extends State<MyPrescriptionsScreen> {
  String t(String english) => AppText.of(context, english);
  late final Future<String> _patientNameFuture;
  final Set<String> _downloadingIds = <String>{};

  @override
  void initState() {
    super.initState();
    // Load patient name on first load
    _patientNameFuture = _loadPatientName();
  }

  // --- Fetch current patient's name from Firestore ---
  Future<String> _loadPatientName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Patient';

    final doc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .get();

    final data = doc.data() ?? <String, dynamic>{};
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final fullName = [
      first,
      last,
    ].where((part) => part.isNotEmpty).join(' ').trim();

    if (fullName.isNotEmpty) return fullName;
    if ((user.displayName ?? '').trim().isNotEmpty)
      return user.displayName!.trim();
    return 'Patient';
  }

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

  // --- Generate safe filename for PDF export ---
  String _safeFileName({required String doctorName, required DateTime date}) {
    final datePart =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final doctorPart = doctorName
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
    return 'aidlink_prescription_${doctorPart.isEmpty ? 'doctor' : doctorPart}_$datePart.pdf';
  }

  // --- Fetch doctor information for prescription display ---
  Future<Map<String, dynamic>> _loadDoctorData(String doctorId) async {
    final snap = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(doctorId)
        .get();

    return snap.data() ?? <String, dynamic>{};
  }

  String _doctorNameFromData(Map<String, dynamic> doctor) {
    final first = (doctor['firstName'] ?? '').toString().trim();
    final last = (doctor['lastName'] ?? '').toString().trim();
    final full = [
      first,
      last,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    return full.isEmpty ? 'Doctor' : 'Dr. $full';
  }

  Future<void> _downloadPdf({
    required String prescriptionId,
    required PrescriptionPdfData pdfData,
    required String fileName,
  }) async {
    setState(() => _downloadingIds.add(prescriptionId));
    try {
      final bytes = await buildPrescriptionPdf(pdfData);
      final savedPath = await savePdfToDevice(bytes: bytes, fileName: fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Prescription PDF downloaded.')),
          action: SnackBarAction(
            label: t('OPEN'),
            onPressed: () {
              Share.shareXFiles([
                XFile(savedPath),
              ], text: t('Prescription PDF'));
            },
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('Could not download PDF.'))));
    } finally {
      if (mounted) {
        setState(() => _downloadingIds.remove(prescriptionId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(body: Center(child: Text(t('User not logged in'))));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('My Prescriptions'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.prescriptions)
            .where('patientId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(t('Unable to load prescriptions right now.')),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final prescriptions = snapshot.data!.docs;
          if (prescriptions.isEmpty) {
            return Center(child: Text(t('No prescriptions available')));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: prescriptions.length,
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

                  return FutureBuilder<String>(
                    future: _patientNameFuture,
                    builder: (context, patientSnap) {
                      final patientName = patientSnap.data ?? 'Patient';
                      final pdfData = PrescriptionPdfData(
                        doctorName: doctorName,
                        patientName: patientName,
                        date: date,
                        diagnosis: diagnosis,
                        advice: advice,
                        followUpDateText: followUpDateText,
                        medicines: medicines,
                      );

                      final fileName = _safeFileName(
                        doctorName: doctorName,
                        date: date,
                      );

                      final isDownloading = _downloadingIds.contains(doc.id);

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doctorName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.heading3
                                              .copyWith(
                                                color: AppColors.primaryGreen,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${t('Date')}: ${_formatDate(date)}',
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                color: Colors.grey[700],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      '${medicines.length} meds',
                                      style: AppTypography.bodyText.copyWith(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                diagnosis.isEmpty
                                    ? t('No diagnosis provided')
                                    : diagnosis,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyText.copyWith(
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (followUpDateText != null)
                                Text(
                                  '${t('Follow up')}: $followUpDateText',
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/prescription-detail',
                                          arguments: {
                                            'doctorName': doctorName,
                                            'date': date,
                                            'diagnosis': diagnosis,
                                            'medicines': medicines,
                                            'advice': advice,
                                            'followUpDateText':
                                                followUpDateText,
                                            'patientName': patientName,
                                          },
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: Text(t('View')),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryGreen,
                                      ),
                                      onPressed: isDownloading
                                          ? null
                                          : () => _downloadPdf(
                                              prescriptionId: doc.id,
                                              pdfData: pdfData,
                                              fileName: fileName,
                                            ),
                                      icon: isDownloading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.download_outlined,
                                              color: Colors.white,
                                            ),
                                      label: Text(
                                        isDownloading
                                            ? t('Downloading...')
                                            : t('Download PDF'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
