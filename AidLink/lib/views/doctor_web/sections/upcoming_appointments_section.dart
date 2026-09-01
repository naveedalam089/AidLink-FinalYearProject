import 'package:flutter/material.dart';
// Purpose: Doctor web section for upcoming appointments (mark complete/no-show, view details).
// File: lib/views/doctor_web/sections/upcoming_appointments_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/services/appointment_lifecycle_service.dart';
import '../../../core/services/notification_service.dart';

class UpcomingAppointmentsSection extends StatelessWidget {
  final Function(String patientId, String appointmentId) onWritePrescription;

  /// Optional callback invoked when the user taps "History" for a patient.
  ///
  /// Receives the `patientId` and the resolved `patientName`. Implementors
  /// should navigate to a patient history view or embed the history UI.
  final Function(String patientId, String patientName)? onViewHistory;

  const UpcomingAppointmentsSection({
    Key? key,
    required this.onWritePrescription,
    this.onViewHistory,
  }) : super(key: key);

  // --- Mark appointment as completed with actual duration ---
  Future<void> _completeAppointment(
    BuildContext context,
    String appointmentId,
  ) async {
    final appointment = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId)
        .get();
    final data = appointment.data() ?? <String, dynamic>{};
    final patientId = (data['patientId'] ?? '').toString();

    final actualDuration = await _askActualDuration(context);
    if (actualDuration == null) return;

    final result = await AppointmentLifecycleService.markCompletedByDoctor(
      appointmentId: appointmentId,
      actualDurationMinutes: actualDuration,
    );

    if (patientId.isNotEmpty) {
      await NotificationService.createNotification(
        recipientId: patientId,
        recipientRole: UserRoles.patient,
        title: 'Appointment completed',
        body: result['recoveredMinutes'] > 0
            ? 'Your appointment was completed. The doctor recovered ${result['recoveredMinutes']} min for follow-up queue.'
            : 'Your doctor marked the appointment as completed.',
        type: 'appointment_completed',
        data: {'appointmentId': appointmentId},
      );
    }

    await NotificationService.notifyAdmins(
      title: 'Appointment completed',
      body: 'A doctor marked an appointment as completed.',
      type: 'appointment_status_changed_by_doctor',
      data: {
        'appointmentId': appointmentId,
        'doctorId': (data['doctorId'] ?? '').toString(),
        'patientId': patientId,
        'status': AppointmentStatus.completed,
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['recoveredMinutes'] > 0
              ? 'Completed. Recovered ${result['recoveredMinutes']} min.'
              : 'Appointment marked as completed.',
        ),
      ),
    );
  }

  // --- Mark appointment as no-show and notify patient/admin ---
  Future<void> _markNoShow(BuildContext context, String appointmentId) async {
    try {
      final appointment = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();
      final data = appointment.data() ?? <String, dynamic>{};
      final patientId = (data['patientId'] ?? '').toString();

      await AppointmentLifecycleService.markNoShow(
        appointmentId: appointmentId,
      );

      if (patientId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Marked as no-show',
          body: 'The doctor marked this appointment as no-show.',
          type: 'appointment_no_show',
          data: {'appointmentId': appointmentId},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Appointment marked no-show',
        body: 'A doctor marked a patient appointment as no-show.',
        type: 'appointment_status_changed_by_doctor',
        data: {
          'appointmentId': appointmentId,
          'doctorId': (data['doctorId'] ?? '').toString(),
          'patientId': patientId,
          'status': AppointmentStatus.noShow,
        },
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment marked as no-show.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<int?> _askActualDuration(BuildContext context) async {
    final controller = TextEditingController(text: '30');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actual Consultation Time'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes',
            hintText: 'e.g. 20',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final doctor = FirebaseAuth.instance.currentUser;

    if (doctor == null) {
      return const Center(child: Text("Doctor not logged in"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Upcoming Appointments", style: AppTypography.heading2),

        const SizedBox(height: AppSpacing.md),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.appointments)
              .where("doctorId", isEqualTo: doctor.uid)
              .where("status", isEqualTo: AppointmentStatus.approved)
              .orderBy("appointmentDate")
              .snapshots(),

          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final appointments = snapshot.data!.docs;
            final now = DateTime.now();
            final upcomingFiltered = appointments.where((doc) {
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
                  if (timeParts.length > 1 &&
                      timeParts[1] == 'PM' &&
                      hour != 12)
                    hour += 12;
                  if (timeParts.length > 1 &&
                      timeParts[1] == 'AM' &&
                      hour == 12)
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
              return const Text("No upcoming appointments");
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcomingFiltered.length,

              itemBuilder: (context, index) {
                final doc = upcomingFiltered[index];
                final data = doc.data() as Map<String, dynamic>;

                final Timestamp ts = data["appointmentDate"];
                final DateTime dateTime = ts.toDate();
                final slot = (data['slot'] as String?)?.trim() ?? '';

                final patientId = data["patientId"];
                final symptoms = data["symptoms"] ?? "";

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("users")
                      .doc(patientId)
                      .get(),

                  builder: (context, patientSnap) {
                    if (!patientSnap.hasData) {
                      return const SizedBox();
                    }

                    final patient =
                        patientSnap.data!.data() as Map<String, dynamic>? ?? {};

                    final patientName =
                        "${patient['firstName']} ${patient['lastName']}";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),

                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),

                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,

                              children: [
                                Text(
                                  patientName,
                                  style: AppTypography.bodyText.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                Text(
                                  slot.isNotEmpty
                                      ? slot
                                      : TimeOfDay.fromDateTime(
                                          dateTime,
                                        ).format(context),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(symptoms, style: AppTypography.bodyText),

                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                /// HISTORY
                                TextButton.icon(
                                  onPressed: () {
                                    onViewHistory?.call(patientId, patientName);
                                  },

                                  icon: const Icon(
                                    Icons.history_outlined,
                                    color: Colors.blue,
                                  ),

                                  label: const Text(
                                    "History",
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// CHAT
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      "/doctor-chat",
                                      arguments: {"patientName": patientName},
                                    );
                                  },

                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    color: AppColors.primaryGreen,
                                  ),

                                  label: const Text(
                                    "Chat",
                                    style: TextStyle(
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// PRESCRIPTION
                                TextButton.icon(
                                  onPressed: () {
                                    onWritePrescription(patientId, doc.id);
                                  },

                                  icon: const Icon(
                                    Icons.medical_services_outlined,
                                    color: Colors.blue,
                                  ),

                                  label: const Text(
                                    "Prescription",
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),

                                const SizedBox(width: 10),

                                /// COMPLETE APPOINTMENT
                                TextButton.icon(
                                  onPressed: () {
                                    _completeAppointment(context, doc.id);
                                  },

                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green,
                                  ),

                                  label: const Text(
                                    "Complete",
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    _markNoShow(context, doc.id);
                                  },
                                  icon: const Icon(
                                    Icons.person_off_outlined,
                                    color: Colors.deepOrange,
                                  ),
                                  label: const Text(
                                    'No-show',
                                    style: TextStyle(color: Colors.deepOrange),
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
      ],
    );
  }
}
