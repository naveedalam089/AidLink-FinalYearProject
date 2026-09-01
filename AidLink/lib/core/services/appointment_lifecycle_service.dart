// Purpose: Helpers and lifecycle management for appointment state transitions.
// File: lib/core/services/appointment_lifecycle_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_values.dart';

class AppointmentCancellationResult {
  final String appliedStatus;
  final bool isLateCancellation;

  const AppointmentCancellationResult({
    required this.appliedStatus,
    required this.isLateCancellation,
  });
}

class AppointmentLifecycleService {
  // --- Cancel appointment and check if within late-cancellation window ---
  static Future<AppointmentCancellationResult> cancelByPatient({
    required String appointmentId,
    int lateCancellationWindowHours = 24,
  }) async {
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId);

    // Fetch current appointment state
    final doc = await docRef.get();
    final data = doc.data() ?? <String, dynamic>{};
    final currentStatus = (data['status'] ?? '').toString();

    // Validate appointment can be cancelled
    final cancellableStatuses = <String>{
      AppointmentStatus.pending,
      AppointmentStatus.approved,
      AppointmentStatus.postponed,
    };
    if (!cancellableStatuses.contains(currentStatus)) {
      throw Exception('This appointment can no longer be cancelled.');
    }

    // Calculate if cancellation is within late-window threshold
    final appointmentDate = _resolveAppointmentDateTime(
      data['appointmentDate'],
      (data['slot'] ?? '').toString(),
    );

    final now = DateTime.now();
    final isLate = appointmentDate != null
        ? appointmentDate.difference(now).inHours < lateCancellationWindowHours
        : false;

    final status = isLate
        ? AppointmentStatus.cancelledLate
        : AppointmentStatus.cancelled;
    final reasonKey = isLate
        ? AppointmentReasonKeys.patientCancelledLate
        : AppointmentReasonKeys.patientCancelled;

    // Update appointment status and metadata
    await docRef.update({
      'status': status,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelledByRole': UserRoles.patient,
      'lateCancellation': isLate,
      'cancelReasonKey': reasonKey,
    });

    return AppointmentCancellationResult(
      appliedStatus: status,
      isLateCancellation: isLate,
    );
  }

  // --- Mark appointment completed and calculate time recovery ---
  static Future<Map<String, dynamic>> markCompletedByDoctor({
    required String appointmentId,
    int? actualDurationMinutes,
  }) async {
    // Fetch appointment and resolve scheduled duration
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId);

    final doc = await docRef.get();
    final data = doc.data() ?? <String, dynamic>{};

    final plannedMinutes =
        _asInt(data['scheduledSlotMinutes']) ??
        _asInt(data['slotDuration']) ??
        30;

    // Calculate actual duration and time recovered
    final actualMinutes =
        actualDurationMinutes != null && actualDurationMinutes > 0
        ? actualDurationMinutes
        : plannedMinutes;

    final recoveredMinutes = plannedMinutes > actualMinutes
        ? plannedMinutes - actualMinutes
        : 0;

    // Update appointment with completion data
    await docRef.update({
      'status': AppointmentStatus.completed,
      'completedAt': FieldValue.serverTimestamp(),
      'actualDurationMinutes': actualMinutes,
      'scheduledSlotMinutes': plannedMinutes,
      'recoveredMinutes': recoveredMinutes,
      'completedByRole': UserRoles.doctor,
    });

    // Return time accounting results
    return {
      'plannedMinutes': plannedMinutes,
      'actualMinutes': actualMinutes,
      'recoveredMinutes': recoveredMinutes,
    };
  }

  // --- Mark patient as no-show for appointment ---
  static Future<void> markNoShow({required String appointmentId}) async {
    final docRef = FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId);

    final doc = await docRef.get();
    final data = doc.data() ?? <String, dynamic>{};
    final currentStatus = (data['status'] ?? '').toString();

    final markableStatuses = <String>{
      AppointmentStatus.approved,
      AppointmentStatus.checkedIn,
      AppointmentStatus.arrivedLate,
    };
    if (!markableStatuses.contains(currentStatus)) {
      throw Exception('This appointment cannot be marked as no-show.');
    }

    // Update status to no-show
    await docRef.update({
      'status': AppointmentStatus.noShow,
      'noShowAt': FieldValue.serverTimestamp(),
      'noShowMarkedByRole': UserRoles.doctor,
      'noShowReasonKey': AppointmentReasonKeys.noShowMarkedByDoctor,
    });
  }

  // --- Helper methods ---
  static DateTime? _resolveAppointmentDateTime(dynamic rawDate, String slot) {
    if (rawDate is! Timestamp) return null;

    // Combine date from Firestore with parsed slot time
    final day = rawDate.toDate();
    final parsed = _parseSlot(slot);
    if (parsed == null) {
      return DateTime(day.year, day.month, day.day);
    }

    return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
  }

  // --- Parse time slot string (e.g., "2:30 PM") ---
  static DateTime? _parseSlot(String slot) {
    final value = slot.trim();
    if (value.isEmpty) return null;

    final pieces = value.split(' ');
    final hm = pieces.first.split(':');
    if (hm.length != 2) return null;

    final rawHour = int.tryParse(hm[0]);
    final minute = int.tryParse(hm[1]);
    if (rawHour == null || minute == null) return null;

    if (pieces.length == 2) {
      final suffix = pieces[1].toUpperCase();
      var hour = rawHour % 12;
      if (suffix == 'PM') hour += 12;
      return DateTime(2000, 1, 1, hour, minute);
    }

    return DateTime(2000, 1, 1, rawHour, minute);
  }

  // --- Coerce value to int with fallback ---
  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
