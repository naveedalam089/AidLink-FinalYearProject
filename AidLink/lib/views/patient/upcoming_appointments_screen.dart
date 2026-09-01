import 'package:flutter/material.dart';
// Purpose: Patient screen for viewing upcoming appointments with cancel and reschedule options.
// File: lib/views/patient/upcoming_appointments_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/app_values.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/appointment_lifecycle_service.dart';
import '../../core/services/notification_service.dart';

class UpcomingAppointmentsScreen extends StatefulWidget {
  const UpcomingAppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<UpcomingAppointmentsScreen> createState() =>
      _UpcomingAppointmentsScreenState();
}

class _UpcomingAppointmentsScreenState
    extends State<UpcomingAppointmentsScreen> {
  bool _isCancelling = false;

  String t(String english) => AppText.of(context, english);

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
    final doctorName = fullName.isEmpty ? 'Doctor' : 'Dr. $fullName';

    return {
      'name': doctorName,
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

  // --- Get relative day label (Today, Tomorrow, In N days, Upcoming) ---
  String _relativeDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return t('Today');
    if (diff == 1) return t('Tomorrow');
    if (diff > 1) return '${t('In')} $diff ${t('days')}';
    return t('Upcoming');
  }

  // --- Cancel appointment using AppointmentLifecycleService ---
  Future<void> _cancelAppointment(String appointmentId) async {
    final appointmentDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId)
        .get();
    final appointmentData = appointmentDoc.data() ?? <String, dynamic>{};
    final doctorId = (appointmentData['doctorId'] ?? '').toString();
    final patientId = (appointmentData['patientId'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t('Cancel Appointment')),
          content: Text(t('Are you sure you want to cancel this appointment?')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('No')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                t('Yes'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      final cancellation = await AppointmentLifecycleService.cancelByPatient(
        appointmentId: appointmentId,
      );

      if (doctorId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: doctorId,
          recipientRole: UserRoles.doctor,
          title: cancellation.isLateCancellation
              ? 'Late appointment cancellation'
              : 'Appointment cancelled',
          body: cancellation.isLateCancellation
              ? 'A patient cancelled close to appointment time.'
              : 'A patient cancelled an approved appointment.',
          type: cancellation.isLateCancellation
              ? 'appointment_cancelled_late'
              : 'appointment_cancelled',
          data: {
            'appointmentId': appointmentId,
            'patientId': patientId,
            'doctorId': doctorId,
            'status': cancellation.appliedStatus,
          },
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Appointment cancelled successfully.'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Could not cancel appointment right now.'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCancelling = false;
        });
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
          t('Upcoming Appointments'),
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
            .where('status', isEqualTo: AppointmentStatus.approved)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(t('Unable to load upcoming appointments right now.')),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final upcomingFiltered = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final dateRaw = data['appointmentDate'];
            final timeRaw = (data['slot'] ?? '').toString();
            try {
              DateTime apptDate;
              if (dateRaw is Timestamp) {
                apptDate = dateRaw.toDate();
              } else {
                apptDate = DateTime.parse(dateRaw.toString());
              }
              if (timeRaw.toString().isNotEmpty) {
                final timeParts = timeRaw.toString().toUpperCase().split(' ');
                final hm = timeParts[0].split(':');
                int hour = int.parse(hm[0]);
                final int minute = hm.length > 1 ? int.parse(hm[1]) : 0;
                if (timeParts.length > 1 && timeParts[1] == 'PM' && hour != 12)
                  hour += 12;
                if (timeParts.length > 1 && timeParts[1] == 'AM' && hour == 12)
                  hour = 0;
                apptDate = DateTime(
                  apptDate.year,
                  apptDate.month,
                  apptDate.day,
                  hour,
                  minute,
                );
              }
              return apptDate.isAfter(now);
            } catch (_) {
              return true;
            }
          }).toList();

          if (upcomingFiltered.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_busy_outlined,
                      color: AppColors.primaryGreen,
                      size: 44,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      t('No upcoming appointments'),
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      t('Book your next consultation to see it here.'),
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/appointment-booking');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: Text(
                        t('Book Appointment'),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: upcomingFiltered.length,

            itemBuilder: (context, index) {
              final appointmentDoc = upcomingFiltered[index];
              final data = appointmentDoc.data() as Map<String, dynamic>;

              final Timestamp timestamp = data['appointmentDate'];
              final DateTime dateTime = timestamp.toDate();

              final String doctorId = data['doctorId'];
              final String slot = (data['slot'] ?? '').toString();
              final String symptoms = (data['symptoms'] ?? '').toString();
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
                  final photoUrl = (doctorData['photoUrl'] ?? '').toString();

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
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : const AssetImage(
                                            'assets/images/default_profile.jpg',
                                          )
                                          as ImageProvider,
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
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _relativeDayLabel(dateTime),
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
                            ],
                          ),

                          if (symptoms.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${t('Symptoms')}: $symptoms',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                // Message Doctor button - only enabled after appointment is accepted
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    // Navigate to 1:1 chat screen with doctor
                                    // Patient must have an accepted appointment to chat
                                    Navigator.pushNamed(
                                      context,
                                      '/patient-chat',
                                      arguments: {
                                        'appointmentId': appointmentDoc.id,
                                        'doctorId': doctorId,
                                        'doctorName': doctorName,
                                      },
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    t('Chat'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isCancelling
                                      ? null
                                      : () => _cancelAppointment(
                                          appointmentDoc.id,
                                        ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _isCancelling
                                        ? t('Cancelling...')
                                        : t('Cancel'),
                                    style: const TextStyle(color: Colors.white),
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
