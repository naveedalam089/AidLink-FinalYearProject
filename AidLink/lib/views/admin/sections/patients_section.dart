// Purpose: Admin section for managing patients (list, search, view details, stats).
// File: lib/views/admin/sections/patients_section.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/admin_activity_service.dart';

class PatientsSection extends StatefulWidget {
  const PatientsSection({Key? key}) : super(key: key);

  @override
  State<PatientsSection> createState() => _PatientsSectionState();
}

class _PatientsSectionState extends State<PatientsSection> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

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

  // --- Open bottom sheet to send patient notification ---
  void _showNotifySheet(String name, String uid) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        var isSending = false;
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: AppSpacing.md,
              right: AppSpacing.md,
              top: AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notify $name', style: AppTypography.heading3),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Enter your message...',
                    filled: true,
                    fillColor: AppColors.backgroundWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.borderGray),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSending ? null : () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isSending
                            ? null
                            : () async {
                                final msg = controller.text.trim();
                                if (msg.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter a message first',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                setModalState(() => isSending = true);
                                try {
                                  await NotificationService.createNotification(
                                    recipientId: uid,
                                    recipientRole: UserRoles.patient,
                                    title: 'Message from Admin',
                                    body: msg,
                                    type: 'admin_custom_message',
                                    data: {'sentBy': UserRoles.admin},
                                  );

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Notification sent to $name',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to send notification',
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setModalState(() => isSending = false);
                                  }
                                }
                              },
                        child: isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text('Send'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Confirm account block action ---
  void _showBlockConfirm(String name, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Patient'),
        content: Text(
          'Are you sure you want to block $name? They will not be able to log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog('Blocking patient...');
              try {
                await FirebaseFirestore.instance
                    .collection(FirestoreCollections.users)
                    .doc(uid)
                    .update({
                      'blocked': true,
                      'blockedAt': FieldValue.serverTimestamp(),
                      'blockedByRole': UserRoles.admin,
                    });

                await AdminActivityService.log(
                  action: 'patient_blocked',
                  targetType: 'user',
                  targetId: uid,
                  summary: 'Admin blocked patient account: $name',
                  metadata: {'patientName': name},
                  actorRole: UserRoles.admin,
                );

                await NotificationService.createNotification(
                  recipientId: uid,
                  recipientRole: UserRoles.patient,
                  title: 'Account blocked',
                  body:
                      'Your account has been blocked by admin. Please contact support.',
                  type: 'account_blocked',
                  data: {'blocked': true},
                );

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name has been blocked')),
                  );
                }
              } catch (_) {
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to block patient')),
                  );
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  // ── Unblock ───────────────────────────────────────────────────────────────
  Future<void> _unblockPatient(String name, String uid) async {
    _showLoadingDialog('Unblocking patient...');
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .update({
            'blocked': false,
            'unblockedAt': FieldValue.serverTimestamp(),
          });

      await AdminActivityService.log(
        action: 'patient_unblocked',
        targetType: 'user',
        targetId: uid,
        summary: 'Admin unblocked patient account: $name',
        metadata: {'patientName': name},
        actorRole: UserRoles.admin,
      );

      await NotificationService.createNotification(
        recipientId: uid,
        recipientRole: UserRoles.patient,
        title: 'Account unblocked',
        body: 'Your account has been unblocked. You can log in again.',
        type: 'account_unblocked',
        data: {'blocked': false},
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$name has been unblocked')));
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock patient')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Text('Patients Management', style: AppTypography.heading1),
          const SizedBox(height: AppSpacing.md),

          // ── Search ───────────────────────────────────────────────────────────
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.borderGray),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Patient list from Firestore ───────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.users)
                .where('role', isEqualTo: UserRoles.patient)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snapshot.data!.docs;

              // Apply search filter
              final filtered = allDocs.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final name =
                    "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                        .toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return name.contains(_searchQuery) ||
                    email.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.people, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No patients found',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final doc = filtered[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final name =
                      "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                          .trim();
                  final email = data['email'] ?? '';
                  final city = data['city'] ?? '';
                  final gender = data['gender'] ?? '';
                  final age = data['age'] ?? '';
                  final blocked = data['blocked'] == true;

                  final Timestamp? ts = data['createdAt'] as Timestamp?;
                  final joinedStr = ts != null
                      ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                      : '—';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: blocked
                          ? Colors.red.withOpacity(0.04)
                          : AppColors.backgroundWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: blocked
                            ? Colors.red.withOpacity(0.3)
                            : AppColors.borderGray,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryGreen.withOpacity(
                            0.1,
                          ),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),

                        const SizedBox(width: AppSpacing.md),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(name, style: AppTypography.heading3),
                                  if (blocked) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.red),
                                      ),
                                      child: const Text(
                                        'BLOCKED',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: AppTypography.bodyText.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 12,
                                children: [
                                  if (age.isNotEmpty)
                                    Text(
                                      'Age: $age',
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (gender.isNotEmpty)
                                    Text(
                                      gender,
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (city.isNotEmpty)
                                    Text(
                                      city,
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  Text(
                                    'Joined: $joinedStr',
                                    style: AppTypography.bodyText.copyWith(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.primaryGreen,
                              ),
                              tooltip: 'Notify',
                              onPressed: () => _showNotifySheet(name, doc.id),
                            ),
                            IconButton(
                              icon: Icon(
                                blocked ? Icons.lock_open : Icons.block,
                                color: blocked ? Colors.green : Colors.red,
                              ),
                              tooltip: blocked ? 'Unblock' : 'Block',
                              onPressed: () => blocked
                                  ? _unblockPatient(name, doc.id)
                                  : _showBlockConfirm(name, doc.id),
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
        ],
      ),
    );
  }
}
