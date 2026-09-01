import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_values.dart';
import 'notification_service.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Set<String> _blockedWords = {
    'fuck',
    'fucking',
    'shit',
    'bitch',
    'bastard',
    'asshole',
    'haramzada',
    'madarchod',
    'behenchod',
    'chutiya',
    'kutta',
    'kameena',
  };

  static String? validateReviewText(String comment) {
    final normalized = comment.toLowerCase();
    for (final word in _blockedWords) {
      final pattern = RegExp(
        '(^|[^a-z])' + RegExp.escape(word) + r'([^a-z]|$)',
      );
      if (pattern.hasMatch(normalized)) {
        return 'Please remove inappropriate language from your feedback.';
      }
    }
    return null;
  }

  static Future<bool> canPatientReviewDoctor({
    required String patientId,
    required String doctorId,
  }) async {
    final completedAppointment = await _firestore
        .collection(FirestoreCollections.appointments)
        .where('patientId', isEqualTo: patientId)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: AppointmentStatus.completed)
        .limit(1)
        .get();

    return completedAppointment.docs.isNotEmpty;
  }

  static Future<void> submitReview({
    required String appointmentId,
    required String patientId,
    required String doctorId,
    required int rating,
    required String comment,
    required String patientName,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('Please select a rating between 1 and 5.');
    }

    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) {
      throw Exception('Please write your feedback comment.');
    }

    final badWordError = validateReviewText(trimmedComment);
    if (badWordError != null) {
      throw Exception(badWordError);
    }

    final appointmentDoc = await _firestore
        .collection(FirestoreCollections.appointments)
        .doc(appointmentId)
        .get();

    final appointmentData = appointmentDoc.data() ?? <String, dynamic>{};
    final isValidCompletedAppointment =
        appointmentDoc.exists &&
        appointmentData['patientId'] == patientId &&
        appointmentData['doctorId'] == doctorId &&
        appointmentData['status'] == AppointmentStatus.completed;

    if (!isValidCompletedAppointment) {
      throw Exception(
        'Feedback can only be submitted for completed appointments.',
      );
    }

    final reviewDocId = '${appointmentId}_$patientId';
    final reviewDocRef = _firestore
        .collection(FirestoreCollections.reviews)
        .doc(reviewDocId);
    final reviewDoc = await reviewDocRef.get();
    if (reviewDoc.exists) {
      throw Exception('You already submitted feedback for this appointment.');
    }

    await reviewDocRef.set({
      'appointmentId': appointmentId,
      'doctorId': doctorId,
      'patientId': patientId,
      'patientName': patientName,
      'rating': rating,
      'comment': trimmedComment,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'approvedAt': null,
      'reviewedAt': null,
      'reviewedBy': null,
      'adminNote': null,
    });

    await NotificationService.notifyAdmins(
      title: 'New doctor feedback pending',
      body: '$patientName submitted feedback awaiting approval.',
      type: 'doctor_feedback_pending',
      data: {'doctorId': doctorId, 'appointmentId': appointmentId},
    );
  }

  static Future<void> recalculateDoctorRating(String doctorId) async {
    final approvedReviews = await _firestore
        .collection(FirestoreCollections.reviews)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: 'approved')
        .get();

    if (approvedReviews.docs.isEmpty) {
      await _firestore
          .collection(FirestoreCollections.doctors)
          .doc(doctorId)
          .set({'rating': 0.0, 'totalReviews': 0}, SetOptions(merge: true));
      return;
    }

    var sum = 0.0;
    for (final doc in approvedReviews.docs) {
      final value = doc.data()['rating'];
      if (value is num) {
        sum += value.toDouble();
      }
    }

    final avg = sum / approvedReviews.docs.length;
    await _firestore
        .collection(FirestoreCollections.doctors)
        .doc(doctorId)
        .set({
          'rating': double.parse(avg.toStringAsFixed(2)),
          'totalReviews': approvedReviews.docs.length,
        }, SetOptions(merge: true));
  }

  static Future<int> recalculateAllDoctorRatings() async {
    final doctors = await _firestore
        .collection(FirestoreCollections.doctors)
        .get();
    var updated = 0;

    for (final doctorDoc in doctors.docs) {
      await recalculateDoctorRating(doctorDoc.id);
      updated++;
    }

    return updated;
  }
}
