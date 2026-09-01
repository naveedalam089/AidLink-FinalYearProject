// Purpose: Validate chat access based on appointment status
// File: lib/core/services/chat_appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_values.dart';

/// Service to check if two users can chat based on their appointment status
/// Chat is only allowed after a doctor accepts a patient's appointment
class ChatAppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _canChatWithStatus(String status) {
    return status == AppointmentStatus.approved ||
        status == 'accepted' ||
        status == AppointmentStatus.completed ||
        status == AppointmentStatus.noShow ||
        status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.cancelledLate;
  }

  static bool _matchesAppointmentParticipantIds({
    required Map<String, dynamic> data,
    required String patientId,
    required String doctorId,
  }) {
    final storedPatientId = (data['patientId'] ?? '').toString();
    final storedDoctorId = (data['doctorId'] ?? '').toString();
    return storedPatientId == patientId && storedDoctorId == doctorId;
  }

  static bool _isChatEligibleAppointment(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    return _canChatWithStatus(status);
  }

  /// Validate chat access using a specific appointment document.
  static Future<bool> canPatientChatFromAppointment({
    required String appointmentId,
    required String patientId,
    required String doctorId,
  }) async {
    try {
      if (appointmentId.trim().isEmpty ||
          patientId.trim().isEmpty ||
          doctorId.trim().isEmpty) {
        return false;
      }

      final doc = await _firestore
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();

      if (!doc.exists) {
        return false;
      }

      final data = doc.data() ?? <String, dynamic>{};
      final matches = _matchesAppointmentParticipantIds(
        data: data,
        patientId: patientId,
        doctorId: doctorId,
      );
      final eligible = _isChatEligibleAppointment(data);
      return matches && eligible;
    } catch (_) {
      return false;
    }
  }

  /// Check if patient and doctor have an accepted appointment
  /// Returns true only if there's at least one chat-eligible appointment between them
  static Future<bool> canPatientChatWithDoctor({
    required String patientId,
    required String doctorId,
  }) async {
    try {
      if (patientId.trim().isEmpty || doctorId.trim().isEmpty) {
        return false;
      }

      // Query the patient's appointments first, then match the doctor and status in memory.
      // This avoids relying on a three-field composite index and works with legacy records.
      final query = await _firestore
          .collection(FirestoreCollections.appointments)
          .where('patientId', isEqualTo: patientId)
          .get();

      final any = query.docs.any((doc) {
        final data = doc.data();
        final matches = _matchesAppointmentParticipantIds(
          data: data,
          patientId: patientId,
          doctorId: doctorId,
        );
        final eligible = _isChatEligibleAppointment(data);
        return matches && eligible;
      });

      return any;
    } catch (_) {
      return false;
    }
  }

  /// Check if doctor and patient have an accepted appointment
  /// (Same logic as above, but for clarity)
  static Future<bool> canDoctorChatWithPatient({
    required String doctorId,
    required String patientId,
  }) async {
    return canPatientChatWithDoctor(patientId: patientId, doctorId: doctorId);
  }

  /// Find the first approved appointment id for a doctor-patient pair.
  /// Returns null if there is no chat-eligible appointment.
  static Future<String?> findApprovedAppointmentIdForPair({
    required String doctorId,
    required String patientId,
  }) async {
    try {
      if (doctorId.trim().isEmpty || patientId.trim().isEmpty) {
        return null;
      }

      final query = await _firestore
          .collection(FirestoreCollections.appointments)
          .where('patientId', isEqualTo: patientId)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final matches = _matchesAppointmentParticipantIds(
          data: data,
          patientId: patientId,
          doctorId: doctorId,
        );
        final eligible = _isChatEligibleAppointment(data);
        if (matches && eligible) {
          return doc.id;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
