// Purpose: Admin section for moderating patient feedback before it appears publicly.
// File: lib/views/admin/sections/feedback_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/review_service.dart';

class FeedbackSection extends StatefulWidget {
  const FeedbackSection({Key? key}) : super(key: key);

  @override
  State<FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<FeedbackSection> {
  String _selectedStatus = 'pending';
  bool _actionBusy = false;
  bool _recalculateBusy = false;
  final Map<String, Map<String, String>> _doctorMetaCache = {};

  Future<void> _recalculateAllRatings() async {
    if (_recalculateBusy) return;
    setState(() => _recalculateBusy = true);

    try {
      final updatedCount = await ReviewService.recalculateAllDoctorRatings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recalculated ratings for $updatedCount doctor profiles.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to recalculate ratings.')),
      );
    } finally {
      if (mounted) {
        setState(() => _recalculateBusy = false);
      }
    }
  }

  Future<Map<String, String>> _loadDoctorMeta(String doctorId) async {
    if (doctorId.trim().isEmpty) {
      return {'name': 'Doctor', 'specialization': 'General'};
    }
    final cached = _doctorMetaCache[doctorId];
    if (cached != null) return cached;

    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(doctorId)
          .get(),
      FirebaseFirestore.instance
          .collection(FirestoreCollections.doctors)
          .doc(doctorId)
          .get(),
    ]);

    final userData = results[0].data() ?? <String, dynamic>{};
    final doctorData = results[1].data() ?? <String, dynamic>{};

    final first = (doctorData['firstName'] ?? userData['firstName'] ?? '')
        .toString();
    final last = (doctorData['lastName'] ?? userData['lastName'] ?? '')
        .toString();
    final full = [
      first,
      last,
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).join(' ');

    final fallback = (doctorData['name'] ?? userData['name'] ?? 'Doctor')
        .toString();
    final resolvedName = full.isNotEmpty ? 'Dr. $full' : fallback;
    final resolvedSpecialization =
        (doctorData['specialization'] ??
                userData['specialization'] ??
                'General')
            .toString();

    final meta = {
      'name': resolvedName,
      'specialization': resolvedSpecialization,
    };
    _doctorMetaCache[doctorId] = meta;
    return meta;
  }

  Future<void> _showRejectWithNoteDialog({
    required String reviewId,
    required String doctorId,
  }) async {
    final noteController = TextEditingController();
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reject Feedback'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add a short note for why this feedback is rejected.'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: noteController,
                maxLines: 3,
                maxLength: 180,
                decoration: const InputDecoration(
                  hintText: 'Admin note (required)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final note = noteController.text.trim();
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a rejection note.'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => submitting = true);
                      await _updateReviewStatus(
                        reviewId: reviewId,
                        doctorId: doctorId,
                        status: 'rejected',
                        adminNote: note,
                      );
                      if (mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReviewStatus({
    required String reviewId,
    required String doctorId,
    required String status,
    String? adminNote,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);

    try {
      final reviewSnapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.reviews)
          .doc(reviewId)
          .get();
      final reviewData = reviewSnapshot.data() ?? <String, dynamic>{};
      final patientId = (reviewData['patientId'] ?? '').toString();
      final patientName = (reviewData['patientName'] ?? 'A patient').toString();
      final ratingValue = (reviewData['rating'] as num?)?.toDouble() ?? 0.0;
      final comment = (reviewData['comment'] ?? '').toString();

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.reviews)
          .doc(reviewId)
          .update({
            'status': status,
            'adminNote': status == 'rejected' ? (adminNote ?? '') : null,
            'reviewedAt': FieldValue.serverTimestamp(),
            'approvedAt': status == 'approved'
                ? FieldValue.serverTimestamp()
                : null,
            'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await ReviewService.recalculateDoctorRating(doctorId);

      // Notifications:
      // 1) Doctor gets notified only when a review is approved.
      // 2) Patient gets notified for approved or rejected review.
      if (status == 'approved') {
        final compactComment = comment.length > 80
            ? '${comment.substring(0, 80)}...'
            : comment;

        if (doctorId.isNotEmpty) {
          await NotificationService.createNotification(
            recipientId: doctorId,
            recipientRole: UserRoles.doctor,
            title: 'New approved patient review',
            body:
                '$patientName added a ${ratingValue.toStringAsFixed(1)}-star review: "$compactComment"',
            type: 'doctor_review_approved',
            data: {
              'reviewId': reviewId,
              'patientId': patientId,
              'patientName': patientName,
              'rating': ratingValue,
            },
          );
        }

        if (patientId.isNotEmpty) {
          await NotificationService.createNotification(
            recipientId: patientId,
            recipientRole: UserRoles.patient,
            title: 'Your review was approved',
            body: 'Your review is now visible on the doctor profile.',
            type: 'patient_review_approved',
            data: {'reviewId': reviewId, 'doctorId': doctorId},
          );
        }
      } else if (status == 'rejected' && patientId.isNotEmpty) {
        final reason = (adminNote ?? '').trim().isNotEmpty
            ? adminNote!.trim()
            : 'It did not meet review guidelines.';

        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Your review was rejected',
          body: 'Reason: $reason',
          type: 'patient_review_rejected',
          data: {'reviewId': reviewId, 'doctorId': doctorId, 'reason': reason},
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Feedback ${status == 'approved' ? 'approved' : 'rejected'}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update feedback status.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _deleteReview({
    required String reviewId,
    required String doctorId,
  }) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);

    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.reviews)
          .doc(reviewId)
          .delete();
      await ReviewService.recalculateDoctorRating(doctorId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Feedback deleted')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete feedback.')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  String _formatDate(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) return 'Unknown date';
    final date = rawTimestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Manage Feedback', style: AppTypography.heading1),
            ),
            ElevatedButton.icon(
              onPressed: _recalculateBusy ? null : _recalculateAllRatings,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              icon: _recalculateBusy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _recalculateBusy ? 'Updating...' : 'Recalculate Ratings',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['pending', 'approved', 'rejected'].map((status) {
            final selected = _selectedStatus == status;
            return ChoiceChip(
              label: Text(status.toUpperCase()),
              selected: selected,
              onSelected: (_) => setState(() => _selectedStatus = status),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.reviews)
                .where('status', isEqualTo: _selectedStatus)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Failed to load feedback list.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final docs =
                  List<QueryDocumentSnapshot>.from(
                    snapshot.data?.docs ?? [],
                  )..sort((a, b) {
                    final adata = a.data() as Map<String, dynamic>;
                    final bdata = b.data() as Map<String, dynamic>;
                    final ats = adata['createdAt'] as Timestamp?;
                    final bts = bdata['createdAt'] as Timestamp?;
                    final ad =
                        ats?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bd =
                        bts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bd.compareTo(ad);
                  });
              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    'No ${_selectedStatus.toLowerCase()} feedback.',
                    style: AppTypography.bodyText,
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  return _buildFeedbackRow(doc.id, data);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackRow(String reviewId, Map<String, dynamic> fb) {
    final doctorId = (fb['doctorId'] ?? '').toString();
    final rating = (fb['rating'] as num?)?.toDouble() ?? 0;
    final comment = (fb['comment'] ?? '').toString();
    final adminNote = (fb['adminNote'] ?? '').toString();
    final patientName = (fb['patientName'] ?? 'Patient').toString();
    final date = _formatDate(fb['createdAt']);

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.md,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<Map<String, String>>(
                  future: _loadDoctorMeta(doctorId),
                  builder: (context, metaSnapshot) {
                    final meta =
                        metaSnapshot.data ??
                        {
                          'name': doctorId.isEmpty ? 'Doctor' : doctorId,
                          'specialization': 'General',
                        };

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta['name'] ?? 'Doctor',
                          style: AppTypography.heading3,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta['specialization'] ?? 'General',
                          style: AppTypography.bodyText.copyWith(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'By: $patientName',
                  style: AppTypography.bodyText.copyWith(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating.round() ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(comment, style: AppTypography.bodyText),
                Text(
                  date,
                  style: AppTypography.bodyText.copyWith(color: Colors.grey),
                ),
                if (_selectedStatus == 'rejected' && adminNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Admin note: $adminNote',
                    style: AppTypography.bodyText.copyWith(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              if (_selectedStatus == 'pending')
                ElevatedButton(
                  onPressed: _actionBusy
                      ? null
                      : () => _updateReviewStatus(
                          reviewId: reviewId,
                          doctorId: doctorId,
                          status: 'approved',
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              if (_selectedStatus == 'pending')
                const SizedBox(width: AppSpacing.sm),
              if (_selectedStatus == 'pending')
                OutlinedButton(
                  onPressed: _actionBusy
                      ? null
                      : () => _showRejectWithNoteDialog(
                          reviewId: reviewId,
                          doctorId: doctorId,
                        ),
                  child: const Text('Reject'),
                ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                onPressed: _actionBusy
                    ? null
                    : () =>
                          _deleteReview(reviewId: reviewId, doctorId: doctorId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
