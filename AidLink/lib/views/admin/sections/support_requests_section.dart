import 'package:cloud_firestore/cloud_firestore.dart';
// Purpose: Admin section for managing support requests (list, search, update status, view details).
// File: lib/views/admin/sections/support_requests_section.dart

import 'package:flutter/material.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/admin_activity_service.dart';

class SupportRequestsSection extends StatefulWidget {
  const SupportRequestsSection({Key? key}) : super(key: key);

  @override
  State<SupportRequestsSection> createState() => _SupportRequestsSectionState();
}

class _SupportRequestsSectionState extends State<SupportRequestsSection> {
  String _selectedStatus = 'open';
  String? _updatingRequestId;
  String? _updatingStatus;

  // --- Update support request status and notify user ---
  Future<void> _updateStatus(String id, String status) async {
    setState(() {
      _updatingRequestId = id;
      _updatingStatus = status;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirestoreCollections.supportRequests)
          .doc(id);

      final doc = await docRef.get();
      final data = doc.data() ?? <String, dynamic>{};
      final userEmail = (data[SupportRequestFields.email] ?? '').toString();

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.supportRequests)
          .doc(id)
          .update({SupportRequestFields.status: status});

      await AdminActivityService.log(
        action: 'support_request_status_updated',
        targetType: 'support_request',
        targetId: id,
        summary: 'Admin updated support request status to $status',
        metadata: {'email': userEmail, 'status': status},
        actorRole: UserRoles.admin,
      );

      if (userEmail.isNotEmpty) {
        String title = '';
        String body = '';
        if (status == 'in_progress') {
          title = 'Support request received';
          body = 'We received your support request and are working on it.';
        } else if (status == 'resolved') {
          title = 'Support request resolved';
          body = 'Your support request has been resolved.';
        }

        if (title.isNotEmpty && body.isNotEmpty) {
          try {
            final userSnap = await FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .where('email', isEqualTo: userEmail)
                .limit(1)
                .get();

            if (userSnap.docs.isNotEmpty) {
              await NotificationService.createNotification(
                recipientId: userSnap.docs.first.id,
                recipientRole: UserRoles.patient,
                title: title,
                body: body,
                type: 'support_request_$status',
                data: {'supportRequestId': id, 'status': status},
              );
            }
          } catch (_) {
            // Silently fail if user lookup fails
          }
        }
      }
    } finally {
      if (mounted && _updatingRequestId == id && _updatingStatus == status) {
        setState(() {
          _updatingRequestId = null;
          _updatingStatus = null;
        });
      }
    }
  }

  // --- Format Firestore timestamp as readable date/time ---
  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}/${d.month}/${d.year} $hh:$mm';
  }

  // --- Get color for status badge ---
  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Support Requests', style: AppTypography.heading1),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderGray),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(
                      value: 'resolved',
                      child: Text('Resolved'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedStatus = value);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.supportRequests)
                .orderBy(SupportRequestFields.createdAt, descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data[SupportRequestFields.status] as String? ??
                        'open') ==
                    _selectedStatus;
              }).toList();
              if (docs.isEmpty) {
                return const Center(child: Text('No support requests found'));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final status =
                      (data[SupportRequestFields.status] as String? ?? 'open');
                  final color = _statusColor(status);

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7EEE8)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                (data[SupportRequestFields.subject]
                                            as String? ??
                                        'No subject')
                                    .trim(),
                                style: AppTypography.heading3,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(18),
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
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${data[SupportRequestFields.name] ?? 'Unknown'} • ${data[SupportRequestFields.email] ?? '-'}',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${data[SupportRequestFields.category] ?? 'Other'} • ${_formatDate(data[SupportRequestFields.createdAt] as Timestamp?)}',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          (data[SupportRequestFields.message] as String? ?? '-')
                              .trim(),
                          style: AppTypography.bodyText,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (status != 'in_progress')
                              TextButton(
                                onPressed: _updatingRequestId == doc.id
                                    ? null
                                    : () =>
                                          _updateStatus(doc.id, 'in_progress'),
                                child:
                                    _updatingRequestId == doc.id &&
                                        _updatingStatus == 'in_progress'
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Mark In Progress'),
                              ),
                            if (status != 'resolved')
                              ElevatedButton(
                                onPressed: _updatingRequestId == doc.id
                                    ? null
                                    : () => _updateStatus(doc.id, 'resolved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                ),
                                child:
                                    _updatingRequestId == doc.id &&
                                        _updatingStatus == 'resolved'
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Resolve'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
