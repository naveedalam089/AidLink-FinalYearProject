// Purpose: Records admin activity logs to Firestore for auditing and admin UI.
// File: lib/core/services/admin_activity_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_values.dart';

class AdminActivityService {
  // --- Firestore connection ---
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Record an admin action/event to activity logs ---
  static Future<void> log({
    required String action,
    required String targetType,
    required String targetId,
    required String summary,
    Map<String, dynamic>? metadata,
    String? actorId,
    String? actorRole,
  }) async {
    // Get current user from Firebase Auth
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Use provided actor ID/role, or default to current user as admin
    final resolvedActorId = actorId ?? currentUser.uid;
    final resolvedActorRole = actorRole ?? UserRoles.admin;

    // Create and store activity log document
    await _firestore.collection(FirestoreCollections.adminActivityLogs).add({
      AdminActivityFields.actorId: resolvedActorId,
      AdminActivityFields.actorRole: resolvedActorRole,
      AdminActivityFields.action: action,
      AdminActivityFields.targetType: targetType,
      AdminActivityFields.targetId: targetId,
      AdminActivityFields.summary: summary,
      AdminActivityFields.metadata: metadata ?? <String, dynamic>{},
      AdminActivityFields.createdAt: FieldValue.serverTimestamp(),
    });
  }
}
