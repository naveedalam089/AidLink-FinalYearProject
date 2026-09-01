import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';

/// Display rejection reason and next steps for rejected doctors.
/// File: lib/views/doctor_mobile/doctor_rejection_feedback_screen.dart

class DoctorRejectionFeedbackScreen extends StatefulWidget {
  const DoctorRejectionFeedbackScreen({Key? key}) : super(key: key);

  @override
  State<DoctorRejectionFeedbackScreen> createState() =>
      _DoctorRejectionFeedbackScreenState();
}

class _DoctorRejectionFeedbackScreenState
    extends State<DoctorRejectionFeedbackScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isResubmitting = false;

  Future<Map<String, dynamic>?> _getRejectionDetails() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('doctors').doc(uid).get();
      final data = doc.data();

      if (data == null) return null;

      return {
        'reason': data['rejectionReason'] ?? 'No specific reason provided',
        'rejectedAt': data['rejectedAt'],
        'email': data['email'] ?? _auth.currentUser?.email,
        'status': data['status'],
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _resubmitApplication() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resubmit Application?'),
        content: const Text(
          'Your status will be reset to pending. Admin will review your updated information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resubmit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Reset doctor status to pending for re-review
      await _firestore
          .collection('doctors')
          .doc(_auth.currentUser!.uid)
          .update({
            'status': 'pending',
            'rejectionReason': null,
            'rejectedAt': null,
            'resubmittedAt': Timestamp.now(),
          });

      if (mounted) {
        setState(() => _isResubmitting = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application reset to pending. Go to Edit Profile to update your information.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (_) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Verification Status',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getRejectionDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text('Unable to load rejection details'),
            );
          }

          final data = snapshot.data!;
          final reason = data['reason'] as String;
          final rejectedAt = data['rejectedAt'] as Timestamp?;
          final email = data['email'] as String?;
          final status = data['status'] as String?;

          // If successfully resubmitted, show confirmation screen
          if (_isResubmitting || status == 'pending') {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Application Reset',
                          style: AppTypography.heading2.copyWith(
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Your application status has been reset to pending',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.green.shade600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outlined,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(
                              child: Text(
                                'Next Steps',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          '1. Go to Edit Profile\n2. Update your documents and information\n3. Make sure to address all feedback points\n4. Submit for review\n\nAdmin will review your updated application within 2-3 business days.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, '/doctor-edit-profile'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Go to Edit Profile'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      side: const BorderSide(color: Colors.grey),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Icon & Status ──────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 64,
                        color: Colors.red.shade600,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Verification Not Approved',
                        style: AppTypography.heading2.copyWith(
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Your doctor profile verification was rejected',
                        style: AppTypography.bodyText.copyWith(
                          color: Colors.red.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Rejection Reason ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outlined,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Rejection Reason',
                            style: AppTypography.heading3,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        reason,
                        style: AppTypography.bodyText.copyWith(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Rejection Date ────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.grey,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rejection Date',
                            style: AppTypography.bodyText.copyWith(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(rejectedAt),
                            style: AppTypography.bodyText.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),

                // ── Next Steps ────────────────────────────────────────
                Text('What Next?', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.md),

                // Step 1: Review
                _buildNextStepTile(
                  icon: Icons.done_outline,
                  title: 'Review the Feedback',
                  description:
                      'Please carefully review the rejection reason above.',
                ),
                const SizedBox(height: AppSpacing.sm),

                // Step 2: Update Information
                _buildNextStepTile(
                  icon: Icons.edit_outlined,
                  title: 'Update Your Information',
                  description:
                      'Click "Resubmit Application" to update your documents and details.',
                ),
                const SizedBox(height: AppSpacing.sm),

                // Step 3: Resubmit
                _buildNextStepTile(
                  icon: Icons.refresh_outlined,
                  title: 'Resubmit Application',
                  description:
                      'Your status will be reset to pending for admin review.',
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Action Buttons ────────────────────────────────────
                // Resubmit Application Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _resubmitApplication,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Resubmit Application'),
                ),

                const SizedBox(height: AppSpacing.md),

                // Logout Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Support Email Info ────────────────────────────────
                if (email != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          color: Colors.blue.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Your account email: $email',
                            style: AppTypography.bodyText.copyWith(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNextStepTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyText.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
