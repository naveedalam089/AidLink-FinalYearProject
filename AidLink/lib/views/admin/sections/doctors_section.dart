import 'package:flutter/material.dart';
// Purpose: Admin section for managing doctors (list, search, verify/reject, view details).
// File: lib/views/admin/sections/doctors_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/services/admin_activity_service.dart';
import '../../../core/services/notification_service.dart';

class DoctorsSection extends StatefulWidget {
  const DoctorsSection({Key? key}) : super(key: key);

  @override
  State<DoctorsSection> createState() => _DoctorsSectionState();
}

class _DoctorsSectionState extends State<DoctorsSection> {
  String _selectedStatus = 'pending';

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  // --- Approve doctor verification ---
  Future<void> _approveDoctor(String uid, String name) async {
    _showLoadingDialog('Approving doctor...');
    try {
      await FirebaseFirestore.instance.collection('doctors').doc(uid).update({
        'status': 'approved',
      });

      await NotificationService.createNotification(
        recipientId: uid,
        recipientRole: UserRoles.doctor,
        title: 'Doctor profile approved',
        body: 'Your doctor verification has been approved by admin.',
        type: 'doctor_verification_approved',
        data: {'doctorId': uid},
      );

      await AdminActivityService.log(
        action: 'doctor_approved',
        targetType: FirestoreCollections.doctors,
        targetId: uid,
        summary: 'Admin approved doctor profile for $name.',
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name has been approved')));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve doctor')),
        );
      }
    }
  }

  // --- Show rejection reason dialog ---
  void _showRejectReasonDialog(String uid, String name) {
    final reasonController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rejection Reason'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please provide a reason for rejecting Dr. $name\'s profile.',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: reasonController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Medical license documents unclear, CNIC verification failed, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(AppSpacing.md),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final reason = reasonController.text.trim();
                      if (reason.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a rejection reason'),
                          ),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);
                      await _rejectDoctor(uid, name, reason);
                      if (mounted) Navigator.pop(dialogContext);
                    },
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reject doctor verification ---
  Future<void> _rejectDoctor(String uid, String name, String reason) async {
    _showLoadingDialog('Rejecting doctor...');
    try {
      await FirebaseFirestore.instance.collection('doctors').doc(uid).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': Timestamp.now(),
      });

      await NotificationService.createNotification(
        recipientId: uid,
        recipientRole: UserRoles.doctor,
        title: 'Doctor profile rejected',
        body: 'Your doctor verification was rejected by admin. $reason',
        type: 'doctor_verification_rejected',
        data: {'doctorId': uid},
      );

      await AdminActivityService.log(
        action: 'doctor_rejected',
        targetType: FirestoreCollections.doctors,
        targetId: uid,
        summary: 'Admin rejected doctor profile for $name. Reason: $reason',
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name has been rejected')));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject doctor')),
        );
      }
    }
  }

  // --- Show doctor details dialog with action buttons ---
  void _showDetails(Map<String, dynamic> d, Map<String, dynamic> u) {
    final name = "${u['firstName'] ?? ''} ${u['lastName'] ?? ''}".trim();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.borderGray,
                      backgroundImage:
                          (d['profilePhotoUrl'] != null &&
                              d['profilePhotoUrl'].toString().isNotEmpty)
                          ? NetworkImage(d['profilePhotoUrl'])
                          : const AssetImage(
                                  'assets/images/default_profile.jpg',
                                )
                                as ImageProvider,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. $name', style: AppTypography.heading2),
                          const SizedBox(height: 4),
                          _statusBadge(d['status'] ?? 'pending'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),

                // ── Personal info ────────────────────────────────────────
                _dialogSection('Personal Information'),
                _dialogRow(
                  Icons.email,
                  'Email',
                  d['email'] ?? u['email'] ?? '—',
                ),
                _dialogRow(Icons.phone, 'Phone', d['phone'] ?? '—'),
                _dialogRow(Icons.credit_card, 'CNIC', d['cnic'] ?? '—'),
                _dialogRow(Icons.person, 'Gender', d['gender'] ?? '—'),
                _dialogRow(Icons.cake, 'Date of Birth', d['dob'] ?? '—'),

                const SizedBox(height: AppSpacing.md),

                // ── Professional info ────────────────────────────────────
                _dialogSection('Professional Information'),
                _dialogRow(
                  Icons.medical_services,
                  'Specialization',
                  d['specialization'] ?? '—',
                ),
                _dialogRow(
                  Icons.school,
                  'Qualification',
                  d['qualification'] ?? '—',
                ),
                _dialogRow(
                  Icons.verified,
                  'License No.',
                  d['licenseNumber'] ?? '—',
                ),
                _dialogRow(
                  Icons.work,
                  'Experience',
                  d['experience'] != null ? '${d['experience']} years' : '—',
                ),
                _dialogRow(
                  Icons.local_hospital,
                  'Hospital',
                  d['hospital'] ?? '—',
                ),
                _dialogRow(Icons.location_on, 'Address', d['address'] ?? '—'),

                const SizedBox(height: AppSpacing.md),

                // ── Documents ────────────────────────────────────────────
                _dialogSection('Uploaded Documents'),
                _documentRow(
                  ctx,
                  'CNIC Front',
                  fileUrl: d['cnicFrontFileUrl']?.toString(),
                  linkUrl: d['cnicFrontLinkUrl']?.toString(),
                  legacyUrl: d['cnicFrontUrl']?.toString(),
                ),
                _documentRow(
                  ctx,
                  'CNIC Back',
                  fileUrl: d['cnicBackFileUrl']?.toString(),
                  linkUrl: d['cnicBackLinkUrl']?.toString(),
                  legacyUrl: d['cnicBackUrl']?.toString(),
                ),
                _documentRow(
                  ctx,
                  'Medical License',
                  fileUrl: d['licenseFileUrl']?.toString(),
                  linkUrl: d['licenseLinkUrl']?.toString(),
                  legacyUrl: d['licenseUrl']?.toString(),
                ),
                _documentRow(
                  ctx,
                  'Degree Certificate',
                  fileUrl: d['degreeFileUrl']?.toString(),
                  linkUrl: d['degreeLinkUrl']?.toString(),
                  legacyUrl: d['degreeUrl']?.toString(),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Actions ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    if (d['status'] != 'approved') ...[
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveDoctor(d['_uid'], name);
                        },
                        child: const Text('Approve'),
                      ),
                    ],
                    if (d['status'] != 'rejected') ...[
                      const SizedBox(width: AppSpacing.sm),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRejectReasonDialog(d['_uid'], name);
                        },
                        child: const Text('Reject'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _dialogSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.heading3.copyWith(color: AppColors.primaryGreen),
      ),
    );
  }

  Widget _dialogRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodyText.copyWith(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyText.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentRow(
    BuildContext ctx,
    String label, {
    String? fileUrl,
    String? linkUrl,
    String? legacyUrl,
  }) {
    final normalizedFileUrl = _normalizeDocValue(fileUrl);
    final normalizedLinkUrl = _normalizeDocValue(linkUrl);
    final normalizedLegacyUrl = _normalizeDocValue(legacyUrl);

    String? effectiveFileUrl = normalizedFileUrl;
    String? effectiveLinkUrl = normalizedLinkUrl;

    // Backward compatibility for previously saved single URL field.
    if (effectiveFileUrl == null &&
        effectiveLinkUrl == null &&
        normalizedLegacyUrl != null) {
      if (_looksLikeManualLink(normalizedLegacyUrl)) {
        effectiveLinkUrl = normalizedLegacyUrl;
      } else {
        effectiveFileUrl = normalizedLegacyUrl;
      }
    }

    final uploaded = effectiveFileUrl != null || effectiveLinkUrl != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: uploaded ? Colors.green : Colors.red,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyText.copyWith(fontSize: 13),
            ),
          ),
          if (uploaded)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (effectiveFileUrl != null)
                  OutlinedButton(
                    onPressed: () => _openDocumentLink(ctx, effectiveFileUrl),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View Upload'),
                  ),
                if (effectiveLinkUrl != null)
                  TextButton(
                    onPressed: () => _openDocumentLink(ctx, effectiveLinkUrl),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Open Link'),
                  ),
              ],
            )
          else
            Text(
              'Not uploaded',
              style: AppTypography.bodyText.copyWith(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  String? _normalizeDocValue(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _looksLikeManualLink(String value) {
    if (value.startsWith('data:')) return false;
    final uri = Uri.tryParse(value);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  Future<void> _openDocumentLink(BuildContext ctx, String? rawUrl) async {
    final url = rawUrl?.trim() ?? '';
    if (url.isEmpty) return;

    // Data URIs cannot be opened in external browser; show raw value for copy.
    if (url.startsWith('data:')) {
      showDialog(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Document Link'),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('Invalid document link')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('Could not open document link')),
      );
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.green;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Doctor Requests', style: AppTypography.heading1),
              // Status filter tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.borderGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: ['pending', 'approved', 'rejected'].map((status) {
                    final isSelected = _selectedStatus == status;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedStatus = status),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryGreen
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[700],
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Stream ────────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('doctors')
                .where('status', isEqualTo: _selectedStatus)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No ${_selectedStatus} requests',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  d['_uid'] = doc.id; // inject uid into map

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(doc.id)
                        .get(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const SizedBox();

                      final u =
                          userSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final name =
                          "${u['firstName'] ?? ''} ${u['lastName'] ?? ''}"
                              .trim();
                      final photoUrl =
                          d['profilePhotoUrl'] ?? u['profilePhotoUrl'];
                      final specialization = d['specialization'] ?? '—';
                      final hospital = d['hospital'] ?? '—';
                      final submittedAt = d['submittedAt'] as Timestamp?;
                      final dateStr = submittedAt != null
                          ? '${submittedAt.toDate().day}/${submittedAt.toDate().month}/${submittedAt.toDate().year}'
                          : '—';

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundWhite,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 6),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Card header ──────────────────────────────
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.borderGray,
                                  backgroundImage:
                                      (photoUrl != null &&
                                          photoUrl.toString().isNotEmpty)
                                      ? NetworkImage(photoUrl) as ImageProvider
                                      : const AssetImage(
                                          'assets/images/default_profile.jpg',
                                        ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Dr. $name',
                                        style: AppTypography.heading3,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        specialization,
                                        style: AppTypography.bodyText.copyWith(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        'Hospital: $hospital',
                                        style: AppTypography.bodyText.copyWith(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _statusBadge(d['status'] ?? 'pending'),
                              ],
                            ),

                            const SizedBox(height: AppSpacing.sm),

                            Text(
                              'Submitted: $dateStr',
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),

                            const SizedBox(height: AppSpacing.md),

                            // ── Actions ───────────────────────────────────
                            isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _outlineBtn(
                                        'View Details',
                                        () => _showDetails(d, u),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      if (d['status'] != 'approved')
                                        _greenBtn(
                                          'Approve',
                                          () => _approveDoctor(doc.id, name),
                                        ),
                                      if (d['status'] != 'rejected') ...[
                                        const SizedBox(height: AppSpacing.sm),
                                        _redBtn(
                                          'Reject',
                                          () => _showRejectReasonDialog(
                                            doc.id,
                                            name,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      _outlineBtn(
                                        'View Details',
                                        () => _showDetails(d, u),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      if (d['status'] != 'approved')
                                        _greenBtn(
                                          'Approve',
                                          () => _approveDoctor(doc.id, name),
                                        ),
                                      if (d['status'] != 'rejected') ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        _redBtn(
                                          'Reject',
                                          () => _showRejectReasonDialog(
                                            doc.id,
                                            name,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _outlineBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primaryGreen),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(color: AppColors.primaryGreen)),
    );
  }

  Widget _greenBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }

  Widget _redBtn(String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label),
    );
  }
}
