import 'package:flutter/material.dart';
// Purpose: Doctor web section for pending appointment requests (approve/reject/view).
// File: lib/views/doctor_web/sections/pending_requests_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/admin_activity_service.dart';

class PendingRequestsSection extends StatelessWidget {
  final Function(String patientName) onChatOpen;

  const PendingRequestsSection({Key? key, required this.onChatOpen})
    : super(key: key);

  // --- Approve/reject pending request and notify stakeholders ---
  Future<void> _updateStatus(String docId, String status) async {
    final appointment = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(docId)
        .get();
    final data = appointment.data() ?? <String, dynamic>{};
    final patientId = (data['patientId'] ?? '').toString();
    final doctorId = (data['doctorId'] ?? '').toString();

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(docId)
        .update({"status": status});

    final isApproved = status == AppointmentStatus.approved;

    if (patientId.isNotEmpty) {
      await NotificationService.createNotification(
        recipientId: patientId,
        recipientRole: UserRoles.patient,
        title: isApproved ? 'Appointment approved' : 'Appointment rejected',
        body: isApproved
            ? 'Your doctor approved your appointment request.'
            : 'Your appointment request was rejected.',
        type: isApproved ? 'appointment_approved' : 'appointment_rejected',
        data: {'appointmentId': docId},
      );
    }

    await NotificationService.notifyAdmins(
      title: isApproved ? 'Appointment approved' : 'Appointment rejected',
      body: isApproved
          ? 'A doctor approved a patient appointment request.'
          : 'A doctor rejected a patient appointment request.',
      type: 'appointment_status_changed_by_doctor',
      data: {
        'appointmentId': docId,
        'doctorId': doctorId,
        'patientId': patientId,
        'status': status,
      },
    );

    await AdminActivityService.log(
      action: isApproved ? 'appointment_approved' : 'appointment_rejected',
      targetType: 'appointment',
      targetId: docId,
      summary: isApproved
          ? 'Doctor approved appointment request from patient'
          : 'Doctor rejected appointment request from patient',
      metadata: {
        'doctorId': doctorId,
        'patientId': patientId,
        'status': status,
      },
      actorId: doctorId,
      actorRole: UserRoles.doctor,
    );
  }

  @override
  Widget build(BuildContext context) {
    // --- Build pending requests list for current doctor ---
    final doctor = FirebaseAuth.instance.currentUser;

    if (doctor == null) {
      return const Center(child: Text("Doctor not logged in"));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pending Appointment Requests', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.md),

        /// 🔥 REAL STREAM
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.appointments)
              .where("doctorId", isEqualTo: doctor.uid)
              .where("status", isEqualTo: AppointmentStatus.pending)
              .orderBy("createdAt", descending: true)
              .snapshots(),

          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final requests = snapshot.data!.docs;
            final now = DateTime.now();
            final upcoming = requests.where((doc) {
              final data = doc.data() as Map<String, dynamic>;

              // Parse the appointment date
              final dateRaw = data['appointmentDate'] ?? data['date'] ?? '';
              final timeRaw =
                  data['slot'] ?? data['time'] ?? data['appointmentTime'] ?? '';

              try {
                // appointmentDate is stored as a Timestamp or a String like '2026-05-05'
                DateTime apptDate;
                if (dateRaw is Timestamp) {
                  apptDate = dateRaw.toDate();
                } else {
                  apptDate = DateTime.parse(dateRaw.toString());
                }

                // Parse time string like '3:00 PM' or '09:45 AM'
                if (timeRaw.toString().isNotEmpty) {
                  final timeParts = timeRaw.toString().toUpperCase().split(' ');
                  final hm = timeParts[0].split(':');
                  int hour = int.parse(hm[0]);
                  final int minute = hm.length > 1 ? int.parse(hm[1]) : 0;
                  if (timeParts.length > 1 &&
                      timeParts[1] == 'PM' &&
                      hour != 12) {
                    hour += 12;
                  }
                  if (timeParts.length > 1 &&
                      timeParts[1] == 'AM' &&
                      hour == 12) {
                    hour = 0;
                  }
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
                return true; // if parsing fails, show it anyway
              }
            }).toList();

            if (upcoming.isEmpty) {
              return const Text("No pending requests");
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: upcoming.length,

              itemBuilder: (context, index) {
                final doc = upcoming[index];
                final data = doc.data() as Map<String, dynamic>;

                final patientId = data["patientId"];
                final symptoms = data["symptoms"] ?? "";
                final slot = data["slot"] ?? "";

                final Timestamp ts = data["appointmentDate"];
                final date = ts.toDate();

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection("users")
                      .doc(patientId)
                      .get(),

                  builder: (context, userSnap) {
                    if (!userSnap.hasData) return const SizedBox();

                    final user =
                        userSnap.data!.data() as Map<String, dynamic>? ?? {};

                    final patientName =
                        "${user['firstName']} ${user['lastName']}";

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),

                      child: ListTile(
                        leading: const Icon(
                          Icons.pending_actions,
                          color: AppColors.primaryGreen,
                        ),

                        title: Text(patientName, style: AppTypography.bodyText),

                        subtitle: Text(
                          "${date.day}/${date.month}/${date.year} • $slot • $symptoms",
                        ),

                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// ✅ APPROVE
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: AppColors.primaryGreen,
                              ),
                              tooltip: 'Approve',
                              onPressed: () async {
                                await _updateStatus(
                                  doc.id,
                                  AppointmentStatus.approved,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Appointment Approved"),
                                  ),
                                );
                              },
                            ),

                            /// ❌ REJECT
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              tooltip: 'Reject',
                              onPressed: () async {
                                await _updateStatus(
                                  doc.id,
                                  AppointmentStatus.rejected,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Appointment Rejected"),
                                  ),
                                );
                              },
                            ),

                            /// 💬 CHAT
                            IconButton(
                              icon: const Icon(
                                Icons.chat,
                                color: AppColors.primaryGreen,
                              ),
                              tooltip: 'Chat',
                              onPressed: () {
                                onChatOpen(patientName);
                              },
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
