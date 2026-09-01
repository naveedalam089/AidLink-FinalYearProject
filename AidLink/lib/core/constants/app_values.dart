// Purpose: Central constants for Firestore collection names and common field keys used across the app.
// File: lib/core/constants/app_values.dart

class FirestoreCollections {
  // --- Firestore collection names ---
  static const String users = 'users';
  static const String doctors = 'doctors';
  static const String appointments = 'appointments';
  static const String reviews = 'reviews';
  static const String doctorAvailability = 'doctor_availability';
  static const String prescriptions = 'prescriptions';
  static const String supportRequests = 'support_requests';
  static const String notifications = 'notifications';
  static const String adminActivityLogs = 'admin_activity_logs';
}

class UserRoles {
  // --- User role values ---
  static const String patient = 'patient';
  static const String doctor = 'doctor';
  static const String admin = 'admin';
}

class DoctorStatus {
  // --- Doctor verification statuses ---
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

class AppointmentStatus {
  // --- Appointment lifecycle statuses ---
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
  static const String cancelledLate = 'cancelled_late';
  static const String noShow = 'no_show';
  static const String checkedIn = 'checked_in';
  static const String inConsultation = 'in_consultation';
  static const String arrivedLate = 'arrived_late';
  static const String postponed = 'postponed';
  static const String completed = 'completed';
}

class AppointmentReasonKeys {
  static const String patientCancelled = 'patient_cancelled';
  static const String patientCancelledLate = 'patient_cancelled_late';
  static const String patientDeclinedPostponedOffer =
      'patient_declined_postponed_offer';
  static const String postponedOfferExpired = 'postponed_offer_expired';
  static const String doctorUnavailable = 'doctor_unavailable';
  static const String noShowMarkedByDoctor = 'no_show_marked_by_doctor';
}

class PrescriptionFields {
  static const String advice = 'advice';
}

class UserSettingsFields {
  static const String settings = 'settings';
  static const String notificationsEnabled = 'notificationsEnabled';
  static const String emailUpdatesEnabled = 'emailUpdatesEnabled';
  static const String appointmentRemindersEnabled =
      'appointmentRemindersEnabled';
  static const String language = 'language';
}

class SupportRequestFields {
  static const String userId = 'userId';
  static const String name = 'name';
  static const String email = 'email';
  static const String category = 'category';
  static const String subject = 'subject';
  static const String message = 'message';
  static const String createdAt = 'createdAt';
  static const String status = 'status';
  static const String source = 'source';
}

class NotificationFields {
  static const String recipientId = 'recipientId';
  static const String recipientRole = 'recipientRole';
  static const String title = 'title';
  static const String body = 'body';
  static const String type = 'type';
  static const String data = 'data';
  static const String isRead = 'isRead';
  static const String createdAt = 'createdAt';
}

class AdminActivityFields {
  static const String actorId = 'actorId';
  static const String actorRole = 'actorRole';
  static const String action = 'action';
  static const String targetType = 'targetType';
  static const String targetId = 'targetId';
  static const String summary = 'summary';
  static const String metadata = 'metadata';
  static const String createdAt = 'createdAt';
}
