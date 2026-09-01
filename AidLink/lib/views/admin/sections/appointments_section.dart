// Purpose: Admin section for managing appointments (list, search, filter, cancel, view details).
// File: lib/views/admin/sections/appointments_section.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/admin_activity_service.dart';

class AppointmentsSection extends StatefulWidget {
  const AppointmentsSection({Key? key}) : super(key: key);

  @override
  State<AppointmentsSection> createState() => _AppointmentsSectionState();
}

class _AppointmentsSectionState extends State<AppointmentsSection> {
  String _selectedStatus = 'All';
  String _selectedReasonKey = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // --- Status and policy filter options ---
  final List<String> _statuses = [
    'All',
    'pending',
    'approved',
    'checked_in',
    'in_consultation',
    'completed',
    'cancelled',
    'cancelled_late',
    'no_show',
    'rejected',
  ];

  final List<String> _reasonKeys = [
    'All',
    AppointmentReasonKeys.doctorUnavailable,
    AppointmentReasonKeys.patientCancelledLate,
    AppointmentReasonKeys.noShowMarkedByDoctor,
  ];

  // --- Convert reason key to readable label ---
  String _reasonLabel(String key) {
    switch (key) {
      case AppointmentReasonKeys.doctorUnavailable:
        return 'Doctor Unavailable';
      case AppointmentReasonKeys.patientCancelledLate:
        return 'Late Cancellation';
      case AppointmentReasonKeys.noShowMarkedByDoctor:
        return 'No-Show';
      default:
        return 'All Policy Reasons';
    }
  }

  // ── Cancel appointment ────────────────────────────────────────────────────
  Future<void> _cancelAppointment(String docId) async {
    final appointment = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(docId)
        .get();
    final data = appointment.data() ?? <String, dynamic>{};
    final patientId = (data['patientId'] ?? '').toString();
    final doctorId = (data['doctorId'] ?? '').toString();

    await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .doc(docId)
        .update({
          'status': AppointmentStatus.cancelled,
          'cancelledAt': FieldValue.serverTimestamp(),
          'cancelledByRole': UserRoles.admin,
          'cancelReason': 'Cancelled by admin',
          'cancelReasonKey': 'admin_cancelled',
        });

    await AdminActivityService.log(
      action: 'appointment_cancelled',
      targetType: FirestoreCollections.appointments,
      targetId: docId,
      summary: 'Admin cancelled an appointment.',
      metadata: {'patientId': patientId, 'doctorId': doctorId},
    );

    if (patientId.isNotEmpty) {
      await NotificationService.createNotification(
        recipientId: patientId,
        recipientRole: UserRoles.patient,
        title: 'Appointment cancelled by admin',
        body: 'An appointment was cancelled by the admin.',
        type: 'appointment_cancelled_admin',
        data: {'appointmentId': docId},
      );
    }

    if (doctorId.isNotEmpty) {
      await NotificationService.createNotification(
        recipientId: doctorId,
        recipientRole: UserRoles.doctor,
        title: 'Appointment cancelled by admin',
        body: 'An appointment assigned to you was cancelled by admin.',
        type: 'appointment_cancelled_admin',
        data: {'appointmentId': docId},
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
    }
  }

  // ── Status badge ──────────────────────────────────────────────────────────
  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case AppointmentStatus.approved:
        color = Colors.blue;
        break;
      case AppointmentStatus.completed:
        color = Colors.green;
        break;
      case AppointmentStatus.checkedIn:
        color = Colors.teal;
        break;
      case AppointmentStatus.inConsultation:
        color = Colors.indigo;
        break;
      case AppointmentStatus.noShow:
        color = Colors.deepOrange;
        break;
      case AppointmentStatus.cancelledLate:
      case AppointmentStatus.rejected:
        color = Colors.redAccent;
        break;
      case AppointmentStatus.cancelled:
        color = Colors.red;
        break;
      default:
        color = Colors.orange; // pending
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Text('Appointments Overview', style: AppTypography.heading1),
          const SizedBox(height: AppSpacing.md),

          // ── Search + Filter row ──────────────────────────────────────────────
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search patient or doctor...',
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
              ),

              // Status filter
              DropdownButton<String>(
                value: _selectedStatus,
                items: _statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(
                          s == 'All'
                              ? 'All Statuses'
                              : s[0].toUpperCase() + s.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedStatus = v!),
              ),

              DropdownButton<String>(
                value: _selectedReasonKey,
                items: _reasonKeys
                    .map(
                      (key) => DropdownMenuItem(
                        value: key,
                        child: Text(_reasonLabel(key)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedReasonKey = v!),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Stream ───────────────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: _selectedStatus == 'All'
                ? FirebaseFirestore.instance
                      .collection(FirestoreCollections.appointments)
                      .orderBy('appointmentDate', descending: true)
                      .snapshots()
                : FirebaseFirestore.instance
                      .collection(FirestoreCollections.appointments)
                      .where('status', isEqualTo: _selectedStatus)
                      .orderBy('appointmentDate', descending: true)
                      .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Error loading appointments',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SelectableText(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyText.copyWith(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ElevatedButton(
                          onPressed: _retryStream,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              final doctorUnavailableCount = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['cancelReasonKey'] ?? '').toString() ==
                    AppointmentReasonKeys.doctorUnavailable;
              }).length;

              final lateCancellationCount = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['cancelReasonKey'] ?? '').toString() ==
                    AppointmentReasonKeys.patientCancelledLate;
              }).length;

              final noShowCount = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data['noShowReasonKey'] ?? '').toString() ==
                    AppointmentReasonKeys.noShowMarkedByDoctor;
              }).length;

              final filteredDocs = docs.where((doc) {
                if (_selectedReasonKey == 'All') return true;

                final data = doc.data() as Map<String, dynamic>;
                final cancelReasonKey = (data['cancelReasonKey'] ?? '')
                    .toString();
                final noShowReasonKey = (data['noShowReasonKey'] ?? '')
                    .toString();

                return cancelReasonKey == _selectedReasonKey ||
                    noShowReasonKey == _selectedReasonKey;
              }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'No appointments found',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _policyMetricCard(
                        title: 'Doctor Unavailable',
                        count: doctorUnavailableCount,
                        color: Colors.red,
                      ),
                      _policyMetricCard(
                        title: 'Late Cancellations',
                        count: lateCancellationCount,
                        color: Colors.deepOrange,
                      ),
                      _policyMetricCard(
                        title: 'No-Show',
                        count: noShowCount,
                        color: Colors.brown,
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final Timestamp ts = data['appointmentDate'];
                      final DateTime date = ts.toDate();
                      final String status =
                          data['status'] ?? AppointmentStatus.pending;
                      final String slot = data['slot'] ?? '';
                      final String symptoms = data['symptoms'] ?? '';
                      final String patientId = data['patientId'] ?? '';
                      final String doctorId = data['doctorId'] ?? '';

                      return FutureBuilder<List<DocumentSnapshot>>(
                        future: Future.wait([
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(patientId)
                              .get(),
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(doctorId)
                              .get(),
                        ]),
                        builder: (context, namesSnap) {
                          if (!namesSnap.hasData) return const SizedBox();

                          final p =
                              namesSnap.data![0].data()
                                  as Map<String, dynamic>? ??
                              {};
                          final d =
                              namesSnap.data![1].data()
                                  as Map<String, dynamic>? ??
                              {};

                          final patientName =
                              "${p['firstName'] ?? ''} ${p['lastName'] ?? ''}"
                                  .trim();
                          final doctorName =
                              "Dr. ${d['firstName'] ?? ''} ${d['lastName'] ?? ''}"
                                  .trim();

                          final reasonKey =
                              (data['cancelReasonKey'] ??
                                      data['noShowReasonKey'] ??
                                      '')
                                  .toString();

                          // Apply search filter
                          if (_searchQuery.isNotEmpty &&
                              !patientName.toLowerCase().contains(
                                _searchQuery,
                              ) &&
                              !doctorName.toLowerCase().contains(
                                _searchQuery,
                              )) {
                            return const SizedBox();
                          }

                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundWhite,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.borderGray),
                              boxShadow: const [
                                BoxShadow(color: Colors.black12, blurRadius: 4),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── Top row: names + status ────────────────────
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.person,
                                                size: 16,
                                                color: AppColors.primaryGreen,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                patientName,
                                                style: AppTypography.heading3,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.medical_services,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                doctorName,
                                                style: AppTypography.bodyText
                                                    .copyWith(
                                                      color: Colors.grey,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    _statusBadge(status),
                                  ],
                                ),

                                if (reasonKey.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  _reasonBadge(reasonKey),
                                ],

                                const SizedBox(height: AppSpacing.sm),
                                const Divider(height: 1),
                                const SizedBox(height: AppSpacing.sm),

                                // ── Details row ────────────────────────────────
                                Wrap(
                                  spacing: AppSpacing.lg,
                                  runSpacing: 4,
                                  children: [
                                    _detailChip(
                                      Icons.calendar_today,
                                      '${date.day}/${date.month}/${date.year}',
                                    ),
                                    if (slot.isNotEmpty)
                                      _detailChip(Icons.access_time, slot),
                                    if (symptoms.isNotEmpty)
                                      _detailChip(Icons.sick, symptoms),
                                  ],
                                ),

                                // ── Cancel button (only for pending/approved) ──
                                if (status == AppointmentStatus.pending ||
                                    status == AppointmentStatus.approved) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _showCancelConfirm(
                                        doc.id,
                                        patientName,
                                      ),
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Cancel',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTypography.bodyText.copyWith(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _reasonBadge(String reasonKey) {
    Color color;
    switch (reasonKey) {
      case AppointmentReasonKeys.doctorUnavailable:
        color = Colors.red;
        break;
      case AppointmentReasonKeys.patientCancelledLate:
        color = Colors.deepOrange;
        break;
      case AppointmentReasonKeys.noShowMarkedByDoctor:
        color = Colors.brown;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _reasonLabel(reasonKey),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _policyMetricCard({
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyText.copyWith(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text('$count', style: AppTypography.heading2.copyWith(color: color)),
        ],
      ),
    );
  }

  void _showCancelConfirm(String docId, String patientName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: Text(
          'Are you sure you want to cancel $patientName\'s appointment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelAppointment(docId);
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _retryStream() {
    setState(() {});
  }
}
