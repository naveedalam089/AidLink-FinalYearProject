import 'package:flutter/material.dart';
// Purpose: Patient screen for viewing past appointments with details and prescriptions.
// File: lib/views/patient/appointment_history_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/app_values.dart';
import '../../core/services/review_service.dart';
import '../../core/localization/app_text.dart';
import '../../core/widgets/user_avatar.dart';

class AppointmentHistoryScreen extends StatefulWidget {
  const AppointmentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentHistoryScreen> createState() =>
      _AppointmentHistoryScreenState();
}

class _AppointmentHistoryScreenState extends State<AppointmentHistoryScreen> {
  String t(String english) => AppText.of(context, english);

  Future<String> _loadPatientDisplayName(String patientId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.users)
        .doc(patientId)
        .get();
    final data = userDoc.data() ?? <String, dynamic>{};
    final first = (data['firstName'] ?? '').toString().trim();
    final last = (data['lastName'] ?? '').toString().trim();
    final full = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
    if (full.isNotEmpty) return full;
    return (data['name'] ?? 'Patient').toString();
  }

  Future<void> _showReviewDialog({
    required String appointmentId,
    required String doctorId,
    required String doctorName,
    required String patientId,
  }) async {
    int selectedRating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final maxWidth = MediaQuery.of(context).size.width * 0.9;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF8EE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.rate_review,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Rate $doctorName',
                                style: AppTypography.heading3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'How was your consultation experience?',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FBF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: List.generate(5, (index) {
                              final star = index + 1;
                              return IconButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => setDialogState(
                                        () => selectedRating = star,
                                      ),
                                icon: Icon(
                                  star <= selectedRating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: Colors.amber,
                                  size: 30,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: commentController,
                          maxLines: 5,
                          maxLength: 400,
                          decoration: InputDecoration(
                            labelText: 'Write your review',
                            hintText:
                                'Share your experience to help other patients.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          'Your review is published only after admin approval.',
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () async {
                                        final comment = commentController.text
                                            .trim();
                                        final validationError =
                                            ReviewService.validateReviewText(
                                              comment,
                                            );
                                        if (validationError != null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(validationError),
                                            ),
                                          );
                                          return;
                                        }

                                        setDialogState(
                                          () => isSubmitting = true,
                                        );
                                        try {
                                          final patientName =
                                              await _loadPatientDisplayName(
                                                patientId,
                                              );
                                          await ReviewService.submitReview(
                                            appointmentId: appointmentId,
                                            patientId: patientId,
                                            doctorId: doctorId,
                                            rating: selectedRating,
                                            comment: comment,
                                            patientName: patientName,
                                          );

                                          if (!mounted) return;
                                          Navigator.pop(dialogContext);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Feedback submitted and pending admin approval.',
                                              ),
                                            ),
                                          );
                                        } catch (e) {
                                          if (!mounted) return;
                                          setDialogState(
                                            () => isSubmitting = false,
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(e.toString()),
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Submit Review'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Fetch doctor profile and specialty from Firestore ---
  Future<Map<String, dynamic>> _loadDoctorProfile(String doctorId) async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection(FirestoreCollections.users).doc(doctorId).get(),
      firestore.collection(FirestoreCollections.doctors).doc(doctorId).get(),
    ]);

    final userData = results[0].data() as Map<String, dynamic>? ?? {};
    final doctorData = results[1].data() as Map<String, dynamic>? ?? {};

    final first = (userData['firstName'] ?? '').toString();
    final last = (userData['lastName'] ?? '').toString();
    final fullName = [
      first,
      last,
    ].where((part) => part.isNotEmpty).join(' ').trim();

    return {
      'name': fullName.isEmpty ? 'Doctor' : 'Dr. $fullName',
      'specialization':
          (doctorData['specialization'] ??
                  userData['specialization'] ??
                  'General')
              .toString(),
      'photoUrl':
          (doctorData['profilePhotoUrl'] ?? userData['profilePhotoUrl'] ?? '')
              .toString(),
    };
  }

  // --- Format date as DD/MM/YYYY ---
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // --- Get relative past label (Today, Yesterday, N days ago) ---
  String _relativePastLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;

    if (diff <= 0) return t('Today');
    if (diff == 1) return t('Yesterday');
    return '$diff ${t('days ago')}';
  }

  // --- Format status as uppercase label ---
  String _statusLabel(String status) {
    if (status.isEmpty) return 'UNKNOWN';
    return status.toUpperCase();
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
          t('Appointment History'),
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
            .collection(FirestoreCollections.appointments)
            .where('patientId', isEqualTo: user.uid)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(t('Unable to load appointment history right now.')),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allAppointments = snapshot.data!.docs;

          final historyAppointments =
              allAppointments.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final status = (data['status'] ?? '').toString();

                return status == AppointmentStatus.completed ||
                    status == AppointmentStatus.cancelled ||
                    status == AppointmentStatus.cancelledLate ||
                    status == AppointmentStatus.noShow ||
                    status == AppointmentStatus.rejected;
              }).toList()..sort((a, b) {
                final ta =
                    (a.data() as Map<String, dynamic>)['appointmentDate']
                        as Timestamp?;
                final tb =
                    (b.data() as Map<String, dynamic>)['appointmentDate']
                        as Timestamp?;

                final da =
                    ta?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final db =
                    tb?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                return db.compareTo(da);
              });

          if (historyAppointments.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history_toggle_off,
                      color: AppColors.primaryGreen,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      t('No past appointments'),
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      t('Completed and cancelled visits will appear here.'),
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/upcoming-appointments');
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: Text(t('View Upcoming')),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: historyAppointments.length,

            itemBuilder: (context, index) {
              final data =
                  historyAppointments[index].data() as Map<String, dynamic>;

              final Timestamp timestamp = data['appointmentDate'] as Timestamp;
              final DateTime dateTime = timestamp.toDate();

              final String doctorId = (data['doctorId'] ?? '').toString();
              final String slot = (data['slot'] ?? '').toString();
              final String symptoms = (data['symptoms'] ?? '').toString();
              final String status = (data['status'] ?? '').toString();
              final String displayTime = slot.isNotEmpty
                  ? slot
                  : TimeOfDay.fromDateTime(dateTime).format(context);

              return FutureBuilder<Map<String, dynamic>>(
                future: _loadDoctorProfile(doctorId),

                builder: (context, doctorSnapshot) {
                  if (!doctorSnapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(minHeight: 2),
                    );
                  }

                  final doctorData = doctorSnapshot.data!;
                  final doctorName = (doctorData['name'] ?? 'Doctor')
                      .toString();
                  final specialization =
                      (doctorData['specialization'] ?? 'General').toString();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    color: AppColors.primaryGreen,

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
                              UserAvatar(
                                photoUrl: (doctorData['profilePhotoUrl'] ?? '')
                                    .toString(),
                                radius: 28,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      doctorName,
                                      style: AppTypography.heading3.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      specialization,
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
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
                                  color: Colors.white.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: AppTypography.bodyText.copyWith(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.md),

                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _metaChip(
                                icon: Icons.calendar_today,
                                label: _formatDate(dateTime),
                              ),
                              _metaChip(
                                icon: Icons.schedule,
                                label: displayTime,
                              ),
                              _metaChip(
                                icon: Icons.history,
                                label: _relativePastLabel(dateTime),
                              ),
                            ],
                          ),

                          if (symptoms.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Symptoms: $symptoms',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (status == AppointmentStatus.completed) ...[
                            const SizedBox(height: AppSpacing.md),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection(FirestoreCollections.reviews)
                                  .where(
                                    'appointmentId',
                                    isEqualTo: historyAppointments[index].id,
                                  )
                                  .where('patientId', isEqualTo: user.uid)
                                  .limit(1)
                                  .snapshots(),
                              builder: (context, reviewSnapshot) {
                                final hasReview =
                                    reviewSnapshot.hasData &&
                                    reviewSnapshot.data!.docs.isNotEmpty;
                                final reviewData = hasReview
                                    ? reviewSnapshot.data!.docs.first.data()
                                          as Map<String, dynamic>
                                    : <String, dynamic>{};
                                final reviewStatus =
                                    (reviewData['status'] ?? '').toString();
                                final adminNote =
                                    (reviewData['adminNote'] ?? '').toString();

                                if (!hasReview) {
                                  return Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showReviewDialog(
                                        appointmentId:
                                            historyAppointments[index].id,
                                        doctorId: doctorId,
                                        doctorName: doctorName,
                                        patientId: user.uid,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                      icon: const Icon(Icons.rate_review),
                                      label: const Text('Leave Review'),
                                    ),
                                  );
                                }

                                final statusColor = reviewStatus == 'approved'
                                    ? Colors.lightGreenAccent.shade100
                                    : reviewStatus == 'rejected'
                                    ? Colors.red.shade200
                                    : Colors.amber.shade100;

                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.95),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reviewStatus == 'approved'
                                            ? 'Your review is approved and visible.'
                                            : reviewStatus == 'rejected'
                                            ? 'Your review was rejected by admin.'
                                            : 'Your review is pending admin approval.',
                                        style: AppTypography.bodyText.copyWith(
                                          color: Colors.black87,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (reviewStatus == 'rejected' &&
                                          adminNote.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Note: $adminNote',
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                color: Colors.black87,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _metaChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodyText.copyWith(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
