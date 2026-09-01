// Purpose: Centralized notification creation with user preference enforcement.
// File: lib/core/services/notification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_values.dart';

class NotificationService {
  // --- Firestore connection ---
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Helper: Parse boolean from any type (string, num, bool) ---
  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
        return true;
      }
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
    }
    return fallback;
  }

  // --- Type classifiers: Check notification type for gating logic ---
  static bool _isAppointmentType(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('appointment') ||
        normalized.contains('postpone') ||
        normalized.contains('no_show') ||
        normalized.contains('rescheduled') ||
        normalized.contains('reminder');
  }

  // Critical notifications bypass user settings
  static bool _isCriticalType(String type) {
    final normalized = type.toLowerCase();
    return normalized == 'account_blocked' ||
        normalized == 'account_unblocked' ||
        normalized.contains('security') ||
        normalized.contains('review_approved') ||
        normalized.contains('review_rejected');
  }

  // Doctor request/verification notifications
  static bool _isDoctorRequestType(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('doctor_request') ||
        normalized.contains('doctor_verification') ||
        normalized.contains('doctor_pending');
  }

  // System-wide announcements
  static bool _isSystemAnnouncementType(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('announcement') || normalized.contains('system');
  }

  // Daily digest summaries
  static bool _isDigestType(String type) {
    return type.toLowerCase().contains('digest');
  }

  // Email-style update notifications
  static bool _isEmailUpdateLikeType(String type) {
    final normalized = type.toLowerCase();
    return normalized.contains('prescription') ||
        normalized.contains('custom_message') ||
        normalized.contains('update') ||
        normalized.contains('email');
  }

  // --- Main gating logic: Check if user settings allow this notification ---
  static Future<bool> _shouldSendNotification({
    required String recipientId,
    required String recipientRole,
    required String type,
  }) async {
    // Critical notifications always go through
    if (_isCriticalType(type)) {
      return true;
    }

    // Fetch user settings to check preferences
    final userSnapshot = await _firestore
        .collection(FirestoreCollections.users)
        .doc(recipientId)
        .get();
    final userData = userSnapshot.data() ?? <String, dynamic>{};

    // Handle admin notification settings
    final normalizedRole = recipientRole.trim().toLowerCase();
    if (normalizedRole == UserRoles.admin) {
      final rawAdminSettings = userData['adminSettings'];
      final adminSettings = rawAdminSettings is Map
          ? Map<String, dynamic>.from(rawAdminSettings)
          : <String, dynamic>{};

      final newDoctorRequestsEnabled = _asBool(
        adminSettings['newDoctorRequestsEnabled'],
        fallback: true,
      );
      final appointmentUpdatesEnabled = _asBool(
        adminSettings['appointmentUpdatesEnabled'],
        fallback: true,
      );
      final dailyDigestEnabled = _asBool(
        adminSettings['dailyDigestEnabled'],
        fallback: false,
      );
      final systemAnnouncementsEnabled = _asBool(
        adminSettings['systemAnnouncementsEnabled'],
        fallback: true,
      );

      if (!newDoctorRequestsEnabled && _isDoctorRequestType(type)) {
        return false;
      }
      if (!appointmentUpdatesEnabled && _isAppointmentType(type)) {
        return false;
      }
      if (!dailyDigestEnabled && _isDigestType(type)) {
        return false;
      }
      if (!systemAnnouncementsEnabled && _isSystemAnnouncementType(type)) {
        return false;
      }

      return true;
    }

    // Handle patient/doctor notification settings
    final rawSettings = userData[UserSettingsFields.settings];
    final settings = rawSettings is Map
        ? Map<String, dynamic>.from(rawSettings)
        : <String, dynamic>{};

    final notificationsEnabled = _asBool(
      settings[UserSettingsFields.notificationsEnabled],
      fallback: true,
    );
    final emailUpdatesEnabled = _asBool(
      settings[UserSettingsFields.emailUpdatesEnabled],
      fallback: true,
    );
    final appointmentRemindersEnabled = _asBool(
      settings[UserSettingsFields.appointmentRemindersEnabled],
      fallback: true,
    );

    if (!notificationsEnabled) {
      return false;
    }
    if (!appointmentRemindersEnabled && _isAppointmentType(type)) {
      return false;
    }
    if (!emailUpdatesEnabled && _isEmailUpdateLikeType(type)) {
      return false;
    }

    return true;
  }

  // --- Create and store a single notification in Firestore ---
  static Future<void> createNotification({
    required String recipientId,
    required String recipientRole,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    // Skip if no recipient
    if (recipientId.trim().isEmpty) return;

    // Check user settings before creating notification
    final canSend = await _shouldSendNotification(
      recipientId: recipientId,
      recipientRole: recipientRole,
      type: type,
    );
    // Exit early if settings don't allow this notification type
    if (!canSend) {
      return;
    }

    await _firestore.collection(FirestoreCollections.notifications).add({
      NotificationFields.recipientId: recipientId,
      NotificationFields.recipientRole: recipientRole,
      NotificationFields.title: title,
          NotificationFields.body: body,
          NotificationFields.type: type,
          NotificationFields.data: data ?? <String, dynamic>{},
      NotificationFields.isRead: false,
      NotificationFields.createdAt: FieldValue.serverTimestamp(),
    });
  }

  // --- Broadcast notification to all admins ---
  static Future<void> notifyAdmins({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    // Query all admin users
    final admins = await _firestore
        .collection(FirestoreCollections.users)
        .where('role', isEqualTo: UserRoles.admin)
        .get();

    // Send notification to each admin
    for (final admin in admins.docs) {
      await createNotification(
        recipientId: admin.id,
        recipientRole: UserRoles.admin,
        title: title,
        body: body,
        type: type,
        data: data,
      );
    }
  }

  // --- Mark all unread notifications as read for a user ---
  static Future<void> markAllAsRead(String userId) async {
    // Fetch all unread notifications for user
    final snapshot = await _firestore
        .collection(FirestoreCollections.notifications)
        .where(NotificationFields.recipientId, isEqualTo: userId)
        .get();

    // Batch update all to read status
    final batch = _firestore.batch();
    // Mark each unread notification as read
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isRead = (data[NotificationFields.isRead] ?? false) == true;
      if (!isRead) {
        batch.update(doc.reference, {NotificationFields.isRead: true});
      }
    }
    await batch.commit();
  }
}
