// Purpose: Admin dashboard overview with metric cards (total users, appointments, completions, etc.) and charts.
// File: lib/views/admin/sections/dashboard_overview.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/app_values.dart';

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({Key? key}) : super(key: key);

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  // --- Fetch all dashboard counts in one query batch ---
  Future<Map<String, int>> _fetchCounts() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));
    final results = await Future.wait([
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'patient')
          .count()
          .get(),
      FirebaseFirestore.instance.collection('appointments').count().get(),
      FirebaseFirestore.instance
          .collection('doctors')
          .where('status', isEqualTo: 'pending')
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('appointments')
          .where('status', isEqualTo: 'completed')
          .count()
          .get(),
      FirebaseFirestore.instance.collection('prescriptions').count().get(),
      // Count doctors who are currently off-duty for today (offDutyUntil within today)
      FirebaseFirestore.instance
          .collection('doctors')
          .where(
            'offDutyUntil',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday),
          )
          .where('offDutyUntil', isLessThan: Timestamp.fromDate(endOfToday))
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('appointments')
          .where(
            'cancelReasonKey',
            isEqualTo: AppointmentReasonKeys.patientCancelledLate,
          )
          .count()
          .get(),
      FirebaseFirestore.instance
          .collection('appointments')
          .where(
            'noShowReasonKey',
            isEqualTo: AppointmentReasonKeys.noShowMarkedByDoctor,
          )
          .count()
          .get(),
    ]);

    return {
      'doctors': results[0].count ?? 0,
      'patients': results[1].count ?? 0,
      'appointments': results[2].count ?? 0,
      'pending': results[3].count ?? 0,
      'completed': results[4].count ?? 0,
      'prescriptions': results[5].count ?? 0,
      'doctorUnavailable': results[6].count ?? 0,
      'lateCancellations': results[7].count ?? 0,
      'noShow': results[8].count ?? 0,
    };
  }

  // ── Recent activity stream ────────────────────────────────────────────────
  Stream<QuerySnapshot> get _recentAppointments => FirebaseFirestore.instance
      .collection('appointments')
      .orderBy('createdAt', descending: true)
      .limit(5)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dashboard Overview', style: AppTypography.heading1),
          const SizedBox(height: AppSpacing.lg),

          // ── Metric cards ─────────────────────────────────────────────────
          FutureBuilder<Map<String, int>>(
            future: _fetchCounts(),
            builder: (context, snapshot) {
              final counts = snapshot.data ?? {};
              final isLoading = !snapshot.hasData;

              final metrics = [
                {
                  'title': 'Total Doctors',
                  'value': isLoading ? '—' : '${counts['doctors']}',
                  'icon': Icons.medical_services,
                },
                {
                  'title': 'Total Patients',
                  'value': isLoading ? '—' : '${counts['patients']}',
                  'icon': Icons.people,
                },
                {
                  'title': 'Total Appointments',
                  'value': isLoading ? '—' : '${counts['appointments']}',
                  'icon': Icons.calendar_today,
                },
                {
                  'title': 'Pending Approvals',
                  'value': isLoading ? '—' : '${counts['pending']}',
                  'icon': Icons.pending_actions,
                },
                {
                  'title': 'Completed',
                  'value': isLoading ? '—' : '${counts['completed']}',
                  'icon': Icons.check_circle_outline,
                },
                {
                  'title': 'Prescriptions',
                  'value': isLoading ? '—' : '${counts['prescriptions']}',
                  'icon': Icons.description_outlined,
                },
                {
                  'title': 'Doctor Unavailable',
                  'value': isLoading ? '—' : '${counts['doctorUnavailable']}',
                  'icon': Icons.person_off,
                },
                {
                  'title': 'Late Cancellations',
                  'value': isLoading ? '—' : '${counts['lateCancellations']}',
                  'icon': Icons.warning_amber_rounded,
                },
                {
                  'title': 'No-Show',
                  'value': isLoading ? '—' : '${counts['noShow']}',
                  'icon': Icons.event_busy,
                },
              ];

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 2 : 3,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.4,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, i) => _metricCard(
                  metrics[i]['title'] as String,
                  metrics[i]['value'] as String,
                  metrics[i]['icon'] as IconData,
                  isLoading,
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Charts row ───────────────────────────────────────────────────
          Text('Analytics Overview', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.md),

          isMobile
              ? Column(
                  children: [
                    _appointmentsChartCard(),
                    const SizedBox(height: AppSpacing.md),
                    _statusPieCard(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _appointmentsChartCard()),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: _statusPieCard()),
                  ],
                ),

          const SizedBox(height: AppSpacing.xl),

          // ── Recent appointments ──────────────────────────────────────────
          Text('Recent Appointments', style: AppTypography.heading2),
          const SizedBox(height: AppSpacing.md),
          _recentAppointmentsCard(),
        ],
      ),
    );
  }

  // ── Metric card ───────────────────────────────────────────────────────────
  Widget _metricCard(String title, String value, IconData icon, bool loading) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: AppTypography.bodyText.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  value,
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
        ],
      ),
    );
  }

  // ── Appointments bar chart — real data ────────────────────────────────────
  Widget _appointmentsChartCard() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('appointments')
          .orderBy('appointmentDate')
          .get(),
      builder: (context, snapshot) {
        // Build monthly counts from real data
        final Map<int, int> monthlyCounts = {
          for (var i = 1; i <= 12; i++) i: 0,
        };

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['appointmentDate'] as Timestamp?;
            if (ts != null) {
              final month = ts.toDate().month;
              monthlyCounts[month] = (monthlyCounts[month] ?? 0) + 1;
            }
          }
        }

        final months = [
          'J',
          'F',
          'M',
          'A',
          'M',
          'J',
          'J',
          'A',
          'S',
          'O',
          'N',
          'D',
        ];
        final maxY = monthlyCounts.values.isEmpty
            ? 10.0
            : (monthlyCounts.values.reduce((a, b) => a > b ? a : b) + 2)
                  .toDouble();

        return _chartCard(
          'Monthly Appointments',
          SizedBox(
            height: 200,
            child: snapshot.hasData
                ? BarChart(
                    BarChartData(
                      maxY: maxY,
                      barGroups: List.generate(12, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: monthlyCounts[i + 1]!.toDouble(),
                              color: AppColors.primaryGreen,
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) => Text(
                              months[v.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (v, _) => Text(
                              v.toInt().toString(),
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                    ),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }

  // ── Status pie chart — real data ──────────────────────────────────────────
  Widget _statusPieCard() {
    return FutureBuilder<List<AggregateQuerySnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance
            .collection('appointments')
            .where('status', isEqualTo: 'pending')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('appointments')
            .where('status', isEqualTo: 'approved')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('appointments')
            .where('status', isEqualTo: 'completed')
            .count()
            .get(),
        FirebaseFirestore.instance
            .collection('appointments')
            .where('status', isEqualTo: 'cancelled')
            .count()
            .get(),
      ]),
      builder: (context, snapshot) {
        final pending = snapshot.data?[0].count ?? 0;
        final approved = snapshot.data?[1].count ?? 0;
        final completed = snapshot.data?[2].count ?? 0;
        final cancelled = snapshot.data?[3].count ?? 0;
        final total = pending + approved + completed + cancelled;

        final sections = [
          _pieSection('Pending', pending, Colors.orange, total),
          _pieSection('Approved', approved, Colors.blue, total),
          _pieSection('Completed', completed, Colors.green, total),
          _pieSection('Cancelled', cancelled, Colors.red, total),
        ];

        return _chartCard(
          'Appointment Status',
          SizedBox(
            height: 200,
            child: !snapshot.hasData
                ? const Center(child: CircularProgressIndicator())
                : total == 0
                ? Center(
                    child: Text(
                      'No data yet',
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 32,
                            sections: sections,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legend('Pending', pending, Colors.orange),
                          _legend('Approved', approved, Colors.blue),
                          _legend('Completed', completed, Colors.green),
                          _legend('Cancelled', cancelled, Colors.red),
                        ],
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  PieChartSectionData _pieSection(
    String title,
    int count,
    Color color,
    int total,
  ) {
    final pct = total == 0 ? 0.0 : (count / total) * 100;
    return PieChartSectionData(
      value: count.toDouble(),
      color: color,
      title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      radius: 48,
    );
  }

  Widget _legend(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label ($count)', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  // ── Recent appointments list ───────────────────────────────────────────────
  Widget _recentAppointmentsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _recentAppointments,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No appointments yet',
              style: AppTypography.bodyText.copyWith(color: Colors.grey),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          child: Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] ?? 'pending';
              final ts = data['appointmentDate'] as Timestamp?;
              final dateStr = ts != null
                  ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                  : '—';

              return FutureBuilder<List<DocumentSnapshot>>(
                future: Future.wait([
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['patientId'] ?? '')
                      .get(),
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(data['doctorId'] ?? '')
                      .get(),
                ]),
                builder: (context, namesSnap) {
                  if (!namesSnap.hasData) return const SizedBox();
                  final p =
                      namesSnap.data![0].data() as Map<String, dynamic>? ?? {};
                  final d =
                      namesSnap.data![1].data() as Map<String, dynamic>? ?? {};
                  final patientName =
                      "${p['firstName'] ?? ''} ${p['lastName'] ?? ''}".trim();
                  final doctorName =
                      "Dr. ${d['firstName'] ?? ''} ${d['lastName'] ?? ''}"
                          .trim();

                  Color statusColor;
                  switch (status) {
                    case 'approved':
                      statusColor = Colors.blue;
                      break;
                    case 'completed':
                      statusColor = Colors.green;
                      break;
                    case 'cancelled':
                      statusColor = Colors.red;
                      break;
                    default:
                      statusColor = Colors.orange;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                      child: const Icon(
                        Icons.calendar_today,
                        color: AppColors.primaryGreen,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      patientName,
                      style: AppTypography.bodyText.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '$doctorName · $dateStr',
                      style: AppTypography.bodyText.copyWith(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.md),
          chart,
        ],
      ),
    );
  }
}
