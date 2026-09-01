// Purpose: Manages doctor off-duty actions (cancelling today's appointments, declining postponed offers, and notifying patients).
// File: lib/core/services/doctor_duty_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_values.dart';
import 'admin_activity_service.dart';
import 'notification_service.dart';

class DoctorDutyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Marks the doctor as off-duty for the rest of the day.
  /// Cancels all remaining appointments and declines pending postponed offers.
  static Future<Map<String, dynamic>> goOffDuty({
    required String doctorId,
    required String doctorName,
  }) async {
    // --- Validate input ---
    if (doctorId.trim().isEmpty) {
      throw Exception('Invalid doctor ID.');
    }

    // --- Calculate today's date range ---
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    // --- Initialize counters ---
    int cancelledCount = 0;
    int declinedCount = 0;
    final affectedPatients = <String>{};

    // --- Fetch today's appointments and pending postponed offers ---
    final appointmentsSnap = await _firestore
        .collection(FirestoreCollections.appointments)
        .where('doctorId', isEqualTo: doctorId)
        .where(
          'appointmentDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
        )
        .where('appointmentDate', isLessThan: Timestamp.fromDate(endOfToday))
        .get();

    // --- Fetch pending postponed offers ---
    final offersSnap = await _firestore
        .collection('postponed_offers')
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'pending')
        .get();

    // --- Prepare batch updates for Firestore ---
    final batch = _firestore.batch();

    // --- Cancel all today's appointments in acceptable states ---
    for (final appointmentDoc in appointmentsSnap.docs) {
      final data = appointmentDoc.data();
      final status = (data['status'] ?? '').toString();
      final patientId = (data['patientId'] ?? '').toString();

      if (status == AppointmentStatus.pending ||
          status == AppointmentStatus.approved ||
          status == AppointmentStatus.checkedIn ||
          status == AppointmentStatus.arrivedLate) {
        batch.update(appointmentDoc.reference, {
          'status': AppointmentStatus.cancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledByRole': UserRoles.doctor,
          'cancelReason': 'Doctor unavailable - went off duty',
          'cancelReasonKey': AppointmentReasonKeys.doctorUnavailable,
        });

        cancelledCount++;
        if (patientId.isNotEmpty) {
          affectedPatients.add(patientId);
        }
      }
    }

    // --- Decline all pending postponed offers ---
    for (final offerDoc in offersSnap.docs) {
      final data = offerDoc.data();
      final patientId = (data['patientId'] ?? '').toString();

      batch.update(offerDoc.reference, {
        'status': 'declined',
        'resolvedAt': FieldValue.serverTimestamp(),
        'declinedReason': 'Doctor unavailable - went off duty',
        'declinedReasonKey': AppointmentReasonKeys.doctorUnavailable,
      });

      declinedCount++;
      if (patientId.isNotEmpty) {
        affectedPatients.add(patientId);
      }
    }

    // --- Commit all batch updates to Firestore ---
    await batch.commit();

    // --- Mark doctor as off-duty until end of today for admin dashboards ---
    await _firestore.collection(FirestoreCollections.doctors).doc(doctorId).set(
      {'offDutyUntil': Timestamp.fromDate(endOfToday), 'isOffDuty': true},
      SetOptions(merge: true),
    );
    final patientIds = affectedPatients.toList();

    // --- Send notifications to all affected patients ---
    for (final patientId in patientIds) {
      await NotificationService.createNotification(
        recipientId: patientId,
        recipientRole: UserRoles.patient,
        title: 'Appointment cancelled',
        body:
            'Your appointment with $doctorName has been cancelled because the doctor is unavailable.',
        type: 'appointment_cancelled_doctor_unavailable',
        data: {'doctorId': doctorId, 'reason': 'doctor_unavailable'},
      );
    }

    // --- Log this admin activity for audit trail ---
    await AdminActivityService.log(
      actorId: doctorId,
      actorRole: UserRoles.doctor,
      action: 'doctor_went_off_duty',
      targetType: 'doctor',
      targetId: doctorId,
      summary:
          'Doctor $doctorName went off duty. Cancelled $cancelledCount appointments and declined $declinedCount postponed offers. Notified $patientIds patients.',
    );

    return {
      'cancelledCount': cancelledCount,
      'declinedCount': declinedCount,
      'affectedPatientCount': patientIds.length,
    };
  }
}
