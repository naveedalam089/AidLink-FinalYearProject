// Purpose: Manages postponed offers lifecycle (expiration, processing) and related notifications.
// File: lib/core/services/postponed_offer_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_values.dart';
import 'admin_activity_service.dart';
import 'notification_service.dart';

class PostponedOfferService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Find and expire stale postponed offers for a user ---
  static Future<void> expireStaleOffersForUser(String userId) async {
    if (userId.trim().isEmpty) return;

    // Query all expired pending offers for this user
    final now = Timestamp.now();
    final snapshot = await _firestore
        .collection('postponed_offers')
        .where('patientId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .where('expiresAt', isLessThanOrEqualTo: now)
        .get();

    // Expire each stale offer
    for (final doc in snapshot.docs) {
      await _expireOfferDoc(doc);
    }
  }

  // --- Process (accept/decline) a postponed appointment offer ---
  static Future<Map<String, dynamic>> processOffer({
    required String offerId,
    required String patientId,
    required String action,
  }) async {
    if (offerId.trim().isEmpty || patientId.trim().isEmpty) {
      throw Exception('Offer is incomplete.');
    }

    final offerRef = _firestore.collection('postponed_offers').doc(offerId);

    return _firestore
        .runTransaction((transaction) async {
          final offerSnap = await transaction.get(offerRef);
          if (!offerSnap.exists) {
            throw Exception('Postponed offer not found.');
          }

          final offer = offerSnap.data() ?? <String, dynamic>{};
          final status = (offer['status'] ?? 'pending').toString();
          final offerPatientId = (offer['patientId'] ?? '').toString();
          final doctorId = (offer['doctorId'] ?? '').toString();
          final appointmentId = (offer['appointmentId'] ?? '').toString();
          final originalSlot = (offer['originalSlot'] ?? '').toString();

          if (offerPatientId != patientId) {
            throw Exception('This offer does not belong to your account.');
          }

          if (status != 'pending') {
            throw Exception('This offer has already been handled.');
          }

          final expiresAt = offer['expiresAt'];
          if (expiresAt is Timestamp &&
              expiresAt.toDate().isBefore(DateTime.now())) {
            transaction.update(offerRef, {
              'status': 'expired',
              'resolvedAt': FieldValue.serverTimestamp(),
            });
            throw Exception('This offer has expired.');
          }

          final appointmentRef = _firestore
              .collection(FirestoreCollections.appointments)
              .doc(appointmentId);
          final appointmentSnap = await transaction.get(appointmentRef);
          if (!appointmentSnap.exists) {
            throw Exception('Appointment not found.');
          }

          final appointment = appointmentSnap.data() ?? <String, dynamic>{};
          final appointmentStatus = (appointment['status'] ?? '').toString();
          if (appointmentStatus != AppointmentStatus.postponed) {
            throw Exception('This appointment is no longer postponed.');
          }

          if (action == 'decline') {
            transaction.update(offerRef, {
              'status': 'declined',
              'resolvedAt': FieldValue.serverTimestamp(),
            });
            transaction.update(appointmentRef, {
              'status': AppointmentStatus.cancelled,
              'cancelledAt': FieldValue.serverTimestamp(),
              'cancelledBy': patientId,
              'cancelledByRole': UserRoles.patient,
              'cancelReason': 'Patient declined postponed offer',
              'cancelReasonKey':
                  AppointmentReasonKeys.patientDeclinedPostponedOffer,
            });
          } else if (action == 'accept') {
            // --- Handle accept action: reschedule to next day ---
            final originalDate =
                _readDate(offer['originalDate']) ??
                _readDate(appointment['appointmentDate']);
            if (originalDate == null) {
              throw Exception('Unable to resolve the appointment date.');
            }

            // Calculate next day from original date
            final nextDay = DateTime(
              originalDate.year,
              originalDate.month,
              originalDate.day,
            ).add(const Duration(days: 1));
            final startOfDay = DateTime(
              nextDay.year,
              nextDay.month,
              nextDay.day,
            );
            final endOfDay = startOfDay.add(const Duration(days: 1));

            // Check for appointment conflicts on the next day
            final conflictSnap = await _firestore
                .collection(FirestoreCollections.appointments)
                .where('doctorId', isEqualTo: doctorId)
                .where(
                  'appointmentDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
                )
                .where(
                  'appointmentDate',
                  isLessThan: Timestamp.fromDate(endOfDay),
                )
                .get();

            // Verify slot is still available
            final hasConflict = conflictSnap.docs.any((doc) {
              if (doc.id == appointmentId) return false;
              final data = doc.data();
              final slot = (data['slot'] ?? '').toString();
              final status = (data['status'] ?? '').toString();
              return slot == originalSlot &&
                  status != AppointmentStatus.cancelled &&
                  status != AppointmentStatus.rejected &&
                  status != AppointmentStatus.postponed;
            });

            if (hasConflict) {
              throw Exception(
                'That slot is no longer available for the next day.',
              );
            }

            // Update appointment to next day with approved status
            transaction.update(appointmentRef, {
              'appointmentDate': Timestamp.fromDate(nextDay),
              'status': AppointmentStatus.approved,
              'postponedResolvedAt': FieldValue.serverTimestamp(),
              'postponedOfferId': offerId,
            });
            transaction.update(offerRef, {
              'status': 'accepted',
              'resolvedAt': FieldValue.serverTimestamp(),
            });
          } else {
            throw Exception('Invalid action.');
          }

          // Return summary of processed offer
          return {
            'appointmentId': appointmentId,
            'doctorId': doctorId,
            'patientId': offerPatientId,
            'slot': originalSlot,
            'action': action,
          };
        })
        .then((result) async {
          // --- Send notifications after transaction succeeds ---
          final appointmentId = result['appointmentId'] as String;
          final doctorId = result['doctorId'] as String;
          final patientIdValue = result['patientId'] as String;
          final slot = result['slot'] as String;
          final action = result['action'] as String;

          // Notify doctor and patient of acceptance
          if (action == 'accept') {
            await NotificationService.createNotification(
              recipientId: doctorId,
              recipientRole: UserRoles.doctor,
              title: 'Postponed appointment accepted',
              body: 'A patient accepted the same-slot next-day reschedule.',
              type: 'postpone_offer_accepted',
              data: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'patientId': patientIdValue,
                'doctorId': doctorId,
                'slot': slot,
              },
            );
            await NotificationService.createNotification(
              recipientId: patientIdValue,
              recipientRole: UserRoles.patient,
              title: 'Appointment rescheduled',
              body:
                  'Your postponed appointment has been moved to the next day.',
              type: 'appointment_rescheduled',
              data: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'doctorId': doctorId,
                'slot': slot,
              },
            );
            await AdminActivityService.log(
              action: 'postponement_accepted',
              targetType: FirestoreCollections.appointments,
              targetId: appointmentId,
              summary: 'Patient accepted a postponed appointment offer.',
              metadata: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'patientId': patientIdValue,
                'doctorId': doctorId,
                'actorId': patientIdValue,
                'actorRole': UserRoles.patient,
              },
              actorId: patientIdValue,
              actorRole: UserRoles.patient,
            );
          } else if (action == 'decline') {
            // Notify doctor and patient of decline
            await NotificationService.createNotification(
              recipientId: doctorId,
              recipientRole: UserRoles.doctor,
              title: 'Postponed offer declined',
              body: 'A patient declined the postponed appointment offer.',
              type: 'postpone_offer_declined',
              data: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'patientId': patientIdValue,
                'doctorId': doctorId,
                'slot': slot,
              },
            );
            await NotificationService.createNotification(
              recipientId: patientIdValue,
              recipientRole: UserRoles.patient,
              title: 'Appointment cancelled',
              body: 'Your postponed appointment has been cancelled.',
              type: 'appointment_cancelled',
              data: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'doctorId': doctorId,
              },
            );
            await AdminActivityService.log(
              action: 'postponement_declined',
              targetType: FirestoreCollections.appointments,
              targetId: appointmentId,
              summary: 'Patient declined a postponed appointment offer.',
              metadata: {
                'offerId': offerId,
                'appointmentId': appointmentId,
                'patientId': patientIdValue,
                'doctorId': doctorId,
                'actorId': patientIdValue,
                'actorRole': UserRoles.patient,
              },
              actorId: patientIdValue,
              actorRole: UserRoles.patient,
            );
          }

          return result;
        });
  }

  static Future<void> _expireOfferDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final offer = doc.data();
    final offerId = doc.id;
    final appointmentId = (offer['appointmentId'] ?? '').toString();
    final patientId = (offer['patientId'] ?? '').toString();
    final doctorId = (offer['doctorId'] ?? '').toString();

    await doc.reference.update({
      'status': 'expired',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    if (appointmentId.isNotEmpty) {
      final appointmentRef = _firestore
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId);
      await _firestore.runTransaction((transaction) async {
        final appointmentSnap = await transaction.get(appointmentRef);
        if (!appointmentSnap.exists) return;
        final appointment = appointmentSnap.data() ?? <String, dynamic>{};
        if ((appointment['status'] ?? '').toString() ==
            AppointmentStatus.postponed) {
          transaction.update(appointmentRef, {
            'status': AppointmentStatus.cancelled,
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'system',
            'cancelledByRole': 'system',
            'cancelReason': 'Postponed offer expired',
            'cancelReasonKey': AppointmentReasonKeys.postponedOfferExpired,
          });
        }
      });
    }

    await NotificationService.createNotification(
      recipientId: patientId,
      recipientRole: UserRoles.patient,
      title: 'Postponed offer expired',
      body: 'Your postponed appointment offer expired before you responded.',
      type: 'postpone_offer_expired',
      data: {
        'offerId': offerId,
        'appointmentId': appointmentId,
        'doctorId': doctorId,
      },
    );
    await NotificationService.createNotification(
      recipientId: doctorId,
      recipientRole: UserRoles.doctor,
      title: 'Postponed offer expired',
      body: 'A postponed appointment offer expired without a response.',
      type: 'postpone_offer_expired',
      data: {
        'offerId': offerId,
        'appointmentId': appointmentId,
        'patientId': patientId,
      },
    );
    await AdminActivityService.log(
      action: 'postponement_expired',
      targetType: FirestoreCollections.appointments,
      targetId: appointmentId,
      summary: 'A postponed appointment offer expired.',
      metadata: {
        'offerId': offerId,
        'appointmentId': appointmentId,
        'patientId': patientId,
        'doctorId': doctorId,
        'actorId': 'system',
        'actorRole': 'system',
      },
      actorId: 'system',
      actorRole: 'system',
    );
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
