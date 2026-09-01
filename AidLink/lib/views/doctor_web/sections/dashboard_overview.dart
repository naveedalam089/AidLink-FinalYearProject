import 'package:flutter/material.dart';
// Purpose: Doctor web dashboard overview with stats (appointments, prescriptions, etc.).
// File: lib/views/doctor_web/sections/dashboard_overview.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/widgets/dashboard_card.dart';
import '../../../core/constants/app_values.dart';

class DashboardOverview extends StatefulWidget {
  final Function(int) onCardTap;

  const DashboardOverview({Key? key, required this.onCardTap})
    : super(key: key);

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  final _authUser = FirebaseAuth.instance.currentUser;

  // --- Load overview counts for upcoming, pending, and completed ---
  Future<Map<String, int>> _loadCounts() async {
    if (_authUser == null) {
      return {'upcoming': 0, 'pending': 0, 'completed': 0};
    }

    final doctorId = _authUser!.uid;

    final upcoming = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: AppointmentStatus.approved)
        .count()
        .get();

    final pending = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: AppointmentStatus.pending)
        .count()
        .get();

    final completed = await FirebaseFirestore.instance
        .collection(FirestoreCollections.appointments)
        .where('doctorId', isEqualTo: doctorId)
        .where('status', isEqualTo: AppointmentStatus.completed)
        .count()
        .get();

    return {
      'upcoming': upcoming.count ?? 0,
      'pending': pending.count ?? 0,
      'completed': completed.count ?? 0,
    };
  }

  // --- Convert appointment status key into label ---
  String _statusLabel(String status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.approved:
        return 'Approved';
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      case AppointmentStatus.rejected:
        return 'Rejected';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Build doctor overview cards and latest activity list ---
    if (_authUser == null) {
      return const Center(child: Text('Doctor not logged in'));
    }

    bool isWide = MediaQuery.of(context).size.width > 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overview', style: AppTypography.heading2),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<Map<String, int>>(
          future: _loadCounts(),
          builder: (context, snapshot) {
            final counts =
                snapshot.data ?? {'upcoming': 0, 'pending': 0, 'completed': 0};

            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isWide ? 3 : 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              children: [
                DashboardCard(
                  title: 'Upcoming Appointments',
                  value: '${counts['upcoming']}',
                  icon: Icons.calendar_today,
                  onTap: () => widget.onCardTap(0),
                ),
                DashboardCard(
                  title: 'Update Schedule',
                  value: '',
                  icon: Icons.schedule,
                  onTap: () => widget.onCardTap(1),
                ),
                DashboardCard(
                  title: 'Pending Requests',
                  value: '${counts['pending']}',
                  icon: Icons.pending_actions,
                  onTap: () => widget.onCardTap(2),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Recent Activity', style: AppTypography.heading3),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.appointments)
              .where('doctorId', isEqualTo: _authUser!.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Failed to load activity: ${snapshot.error}',
                style: AppTypography.bodyText.copyWith(color: Colors.red),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...snapshot.data!.docs];
            docs.sort((a, b) {
              final aTs =
                  (a.data() as Map<String, dynamic>)['appointmentDate']
                      as Timestamp?;
              final bTs =
                  (b.data() as Map<String, dynamic>)['appointmentDate']
                      as Timestamp?;
              final aMs = aTs?.millisecondsSinceEpoch ?? 0;
              final bMs = bTs?.millisecondsSinceEpoch ?? 0;
              return bMs.compareTo(aMs);
            });
            final recentDocs = docs.take(5).toList();

            if (recentDocs.isEmpty) {
              return const Text('No recent activity');
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recentDocs.length,
              itemBuilder: (context, index) {
                final data = recentDocs[index].data() as Map<String, dynamic>;
                final patientId = data['patientId'] as String? ?? '';
                final status =
                    (data['status'] as String? ?? AppointmentStatus.pending)
                        .toLowerCase();
                final ts = data['appointmentDate'] as Timestamp?;
                final date = ts?.toDate();
                final dateLabel = date == null
                    ? '-'
                    : '${date.day}/${date.month}/${date.year}';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection(FirestoreCollections.users)
                      .doc(patientId)
                      .get(),
                  builder: (context, userSnap) {
                    final userData =
                        userSnap.data?.data() as Map<String, dynamic>? ?? {};
                    final patientName =
                        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                            .trim();

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.medical_services,
                          color: AppColors.primaryGreen,
                        ),
                        title: Text(
                          'Appointment ${_statusLabel(status)}',
                          style: AppTypography.bodyText,
                        ),
                        subtitle: Text(
                          'Patient: ${patientName.isEmpty ? 'Unknown' : patientName} • $dateLabel',
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}
