// Purpose: Admin section for viewing all recorded system activity logs with filters and timestamps.
// File: lib/views/admin/sections/activity_logs_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';

class ActivityLogsSection extends StatelessWidget {
  const ActivityLogsSection({Key? key}) : super(key: key);

  // --- Format Firestore timestamp to readable date/time ---
  String _formatTime(dynamic value) {
    if (value is! Timestamp) return 'Now';
    final date = value.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // --- Choose display color by action type ---
  Color _actionColor(String action) {
    if (action.contains('approve')) return Colors.green;
    if (action.contains('reject') || action.contains('cancel'))
      return Colors.red;
    return AppColors.primaryGreen;
  }

  @override
  Widget build(BuildContext context) {
    // --- Stream and render admin activity log entries ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin Activity Logs', style: AppTypography.heading1),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.adminActivityLogs)
                .orderBy(AdminActivityFields.createdAt, descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Could not load activity logs.'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Text(
                    'No admin activity yet.',
                    style: AppTypography.bodyText.copyWith(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final action = (data[AdminActivityFields.action] ?? '')
                      .toString();
                  final summary = (data[AdminActivityFields.summary] ?? '')
                      .toString();
                  final targetType =
                      (data[AdminActivityFields.targetType] ?? '').toString();
                  final targetId = (data[AdminActivityFields.targetId] ?? '')
                      .toString();
                  final createdAt = data[AdminActivityFields.createdAt];
                  final color = _actionColor(action);

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: color, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                action.replaceAll('_', ' ').toUpperCase(),
                                style: AppTypography.bodyText.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(createdAt),
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(summary, style: AppTypography.bodyText),
                        const SizedBox(height: 4),
                        Text(
                          'Target: $targetType ($targetId)',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[700],
                            fontSize: 12,
                          ),
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
