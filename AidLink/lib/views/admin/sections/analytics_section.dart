// File: lib/views/admin/sections/analytics_section.dart
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
// Purpose: Admin section for viewing analytics charts and detailed statistics.
// File: lib/views/admin/sections/analytics_section.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/utils/csv_download.dart';

class AnalyticsSection extends StatefulWidget {
  const AnalyticsSection({Key? key}) : super(key: key);

  @override
  State<AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<AnalyticsSection> {
  // Real data loaded from Firestore
  Map<String, int> monthlyAppointments = {
    'Jan': 0,
    'Feb': 0,
    'Mar': 0,
    'Apr': 0,
    'May': 0,
    'Jun': 0,
    'Jul': 0,
    'Aug': 0,
    'Sep': 0,
    'Oct': 0,
    'Nov': 0,
    'Dec': 0,
  };

  // --- Specialty distribution data ---
  Map<String, double> specialtyDistribution = {};

  List<FlSpot> activeUsersSpots = [FlSpot(0, 0)];

  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    // --- Load analytics data from Firestore ---
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    // --- Aggregate monthly appointment data ---
    final apptSnap = await FirebaseFirestore.instance
        .collection('appointments')
        .get();

    final Map<String, int> monthly = {
      'Jan': 0,
      'Feb': 0,
      'Mar': 0,
      'Apr': 0,
      'May': 0,
      'Jun': 0,
      'Jul': 0,
      'Aug': 0,
      'Sep': 0,
      'Oct': 0,
      'Nov': 0,
      'Dec': 0,
    };
    final monthKeys = monthly.keys.toList();

    for (final doc in apptSnap.docs) {
      final data = doc.data();
      final ts = data['appointmentDate'] as Timestamp?;
      if (ts != null) {
        final month = ts.toDate().month - 1;
        monthly[monthKeys[month]] = (monthly[monthKeys[month]] ?? 0) + 1;
      }
    }

    // 2. Specialty distribution from approved doctors
    final doctorSnap = await FirebaseFirestore.instance
        .collection('doctors')
        .where('status', isEqualTo: 'approved')
        .get();

    final Map<String, int> specCount = {};
    for (final doc in doctorSnap.docs) {
      final spec = (doc.data()['specialization'] as String? ?? 'Other').trim();
      final key = spec.isEmpty ? 'Other' : spec;
      specCount[key] = (specCount[key] ?? 0) + 1;
    }

    // Convert to percentages
    final total = specCount.values.fold(0, (a, b) => a + b);
    final Map<String, double> specDist = {};
    if (total > 0) {
      specCount.forEach((k, v) {
        specDist[k] = (v / total) * 100;
      });
    }

    // 3. Weekly active users — count appointments created in last 7 days
    final now = DateTime.now();
    final List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final count = apptSnap.docs.where((doc) {
        final data = doc.data();
        final ts = data['createdAt'] as Timestamp?;
        if (ts == null) return false;
        final d = ts.toDate();
        return d.isAfter(startOfDay) && d.isBefore(endOfDay);
      }).length;
      spots.add(FlSpot((6 - i).toDouble(), count.toDouble()));
    }

    // 4. Counts
    final patientCount = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'patient')
        .count()
        .get();
    final doctorCount = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'doctor')
        .count()
        .get();
    final pendingCount = await FirebaseFirestore.instance
        .collection('doctors')
        .where('status', isEqualTo: 'pending')
        .count()
        .get();
    final completedCount = await FirebaseFirestore.instance
        .collection('appointments')
        .where('status', isEqualTo: 'completed')
        .count()
        .get();
    final prescriptionCount = await FirebaseFirestore.instance
        .collection('prescriptions')
        .count()
        .get();

    if (mounted) {
      setState(() {
        monthlyAppointments = monthly;
        specialtyDistribution = specDist.isEmpty ? {'No data': 100} : specDist;
        activeUsersSpots = spots.isEmpty ? [FlSpot(0, 0)] : spots;
        _totalAppointments = apptSnap.docs.length;
        _totalPatients = patientCount.count ?? 0;
        _totalDoctors = doctorCount.count ?? 0;
        _pendingApprovals = pendingCount.count ?? 0;
        _completedAppointments = completedCount.count ?? 0;
        _totalPrescriptions = prescriptionCount.count ?? 0;
        _dataLoaded = true;
      });
    }
  }

  // --- UI State ---
  String _selectedRange = 'Last 3 Months';
  int _tappedBarIndex = -1;
  int _tappedPieIndex = -1;
  int _tappedLineIndex = -1;

  final List<String> _ranges = [
    'Last 3 Months',
    'Last 6 Months',
    'Last 12 Months',
    'Year to Date',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final bool isWide = width > 1000;
        final bool isMedium = width > 700 && width <= 1000;

        Widget mainContent;

        if (isWide) {
          mainContent = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildLeftColumn()),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 1, child: _buildRightColumn()),
            ],
          );
        } else if (isMedium) {
          mainContent = Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildMetricCardsGrid(crossAxisCount: 2)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _buildPieCard()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildLineCard(),
              const SizedBox(height: AppSpacing.md),
              _buildBarCard(),
            ],
          );
        } else {
          // mobile / narrow
          mainContent = Column(
            children: [
              _buildMetricCardsGrid(crossAxisCount: 2),
              const SizedBox(height: AppSpacing.md),
              _buildBarCard(),
              const SizedBox(height: AppSpacing.md),
              _buildLineCard(),
              const SizedBox(height: AppSpacing.md),
              _buildPieCard(),
              const SizedBox(height: AppSpacing.md),
              _buildRecentActivityCard(),
            ],
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderControls(),
              const SizedBox(height: AppSpacing.lg),
              mainContent,
            ],
          ),
        );
      },
    );
  }

  // ------------------ HEADER + CONTROLS ------------------
  Widget _buildHeaderControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text('Analytics', style: AppTypography.heading1)),
        Flexible(
          child: Align(
            alignment: Alignment.topRight,
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.end,
              children: [
                DropdownButton<String>(
                  value: _selectedRange,
                  items: _ranges
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _selectedRange = val);
                  },
                ),
                ElevatedButton.icon(
                  onPressed: _exportCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white, // white text & icon
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _exportHtmlReport,
                  icon: const Icon(Icons.insert_chart_outlined),
                  label: const Text('Export Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ------------------ LEFT / MAIN COLUMN (charts) ------------------
  Widget _buildLeftColumn() {
    return Column(
      children: [
        _buildMetricCardsGrid(crossAxisCount: 3),
        const SizedBox(height: AppSpacing.md),
        _buildBarCard(),
        const SizedBox(height: AppSpacing.md),
        _buildLineCard(),
      ],
    );
  }

  // ------------------ RIGHT COLUMN (pie + recent) ------------------
  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildPieCard(),
        const SizedBox(height: AppSpacing.md),
        _buildRecentActivityCard(),
      ],
    );
  }

  // ------------------ Metric cards ------------------
  int _totalAppointments = 0;
  int _totalPatients = 0;
  int _totalDoctors = 0;
  int _pendingApprovals = 0;
  int _completedAppointments = 0;
  int _totalPrescriptions = 0;

  Widget _buildMetricCardsGrid({int crossAxisCount = 2}) {
    final metrics = [
      {
        'title': 'Total Appointments',
        'value': _dataLoaded ? '$_totalAppointments' : '—',
      },
      {
        'title': 'Total Patients',
        'value': _dataLoaded ? '$_totalPatients' : '—',
      },
      {'title': 'Total Doctors', 'value': _dataLoaded ? '$_totalDoctors' : '—'},
      {'title': 'Avg. Rating', 'value': '4.7'},
      {
        'title': 'Pending Approvals',
        'value': _dataLoaded ? '$_pendingApprovals' : '—',
      },
      {
        'title': 'Prescriptions',
        'value': _dataLoaded ? '$_totalPrescriptions' : '—',
      },
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      // More height per card to avoid overflow
      childAspectRatio: 1.6,
      children: metrics.map((m) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      m['title']!,
                      style: AppTypography.bodyText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      m['value']!,
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ------------------ Bar Chart Card ------------------
  Widget _buildBarCard() {
    if (!_dataLoaded) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final months = monthlyAppointments.keys.toList();
    final values = monthlyAppointments.values.toList();
    final maxValue = values.fold(0, (a, b) => a > b ? a : b).toDouble();
    final double interval = maxValue == 0 ? 5 : (maxValue / 4).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Appointments', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (response == null || response.spot == null) return;
                    setState(() {
                      _tappedBarIndex = response.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxValue + interval) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: AppTypography.bodyText.copyWith(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            months[i],
                            style: AppTypography.bodyText.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(show: true),
                barGroups: List.generate(months.length, (i) {
                  final isTouched = i == _tappedBarIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: values[i].toDouble(),
                        color: isTouched
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withOpacity(0.8),
                        width: isTouched ? 18 : 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }),
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue + interval,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Tap a bar to highlight',
              style: AppTypography.bodyText.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ Line Chart Card ------------------
  Widget _buildLineCard() {
    if (!_dataLoaded || activeUsersSpots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final maxYValue = activeUsersSpots
        .map((e) => e.y)
        .fold(0.0, (a, b) => a > b ? a : b);
    final minYValue = activeUsersSpots
        .map((e) => e.y)
        .fold(double.infinity, (a, b) => a < b ? a : b);
    final range = maxYValue - minYValue;
    final double interval = max(
      20,
      (range / 4).ceilToDouble(),
    ); // at least step of 20

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Users (weekly)', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: max(0, minYValue - interval),
                maxY: maxYValue + interval,
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  touchCallback: (event, response) {
                    if (response == null ||
                        response.lineBarSpots == null ||
                        response.lineBarSpots!.isEmpty) {
                      return;
                    }
                    final spot = response.lineBarSpots!.first;
                    setState(() {
                      _tappedLineIndex = spot.spotIndex;
                    });
                  },
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AppTypography.bodyText.copyWith(fontSize: 11),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            'D${value.toInt() + 1}',
                            style: AppTypography.bodyText.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: activeUsersSpots,
                    isCurved: true,
                    color: AppColors.primaryGreen,
                    dotData: FlDotData(show: true),
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primaryGreen.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ Pie Chart Card ------------------
  Widget _buildPieCard() {
    if (!_dataLoaded || specialtyDistribution.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Specialty Distribution', style: AppTypography.heading3),
            const SizedBox(height: AppSpacing.lg),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      );
    }
    final entries = specialtyDistribution.entries.toList();
    final total = specialtyDistribution.values.fold(0.0, (a, b) => a + b);
    if (total == 0) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Specialty Distribution', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 36,
                      sections: List.generate(entries.length, (i) {
                        final e = entries[i];
                        final isSelected = i == _tappedPieIndex;
                        final color = _colorForIndex(i);
                        return PieChartSectionData(
                          value: e.value,
                          title:
                              '${((e.value / total) * 100).toStringAsFixed(0)}%',
                          radius: isSelected ? 64 : 48,
                          titleStyle: AppTypography.bodyText.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          color: color,
                          badgeWidget: isSelected ? _buildBadge(e.key) : null,
                          badgePositionPercentageOffset: .98,
                        );
                      }),
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (response == null ||
                              response.touchedSection == null) {
                            return;
                          }
                          setState(() {
                            _tappedPieIndex =
                                response.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Legend – custom row layout so text doesn't look broken
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: entries.asMap().entries.map((me) {
                      final idx = me.key;
                      final e = me.value;
                      final color = _colorForIndex(idx);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: InkWell(
                          onTap: () {
                            setState(() => _tappedPieIndex = idx);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.key,
                                  style: AppTypography.bodyText,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${e.value.toStringAsFixed(0)}%',
                                style: AppTypography.bodyText.copyWith(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ Recent Activity ------------------
  Widget _buildRecentActivityCard() {
    final List<Map<String, String>> activities = [
      {
        'title': 'New doctor verified',
        'subtitle': 'Dr. Sarah Johnson',
        'time': '2h ago',
      },
      {
        'title': 'Appointment canceled',
        'subtitle': 'Patient: Ali R',
        'time': '6h ago',
      },
      {
        'title': 'Prescription uploaded',
        'subtitle': 'Patient: John D',
        'time': 'Yesterday',
      },
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTypography.heading3),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView.separated(
              itemCount: activities.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, i) {
                final a = activities[i];
                return ListTile(
                  dense: true,
                  title: Text(a['title']!, style: AppTypography.bodyText),
                  subtitle: Text(
                    a['subtitle']!,
                    style: AppTypography.bodyText.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  trailing: Text(
                    a['time']!,
                    style: AppTypography.bodyText.copyWith(color: Colors.grey),
                  ),
                  onTap: () {
                    // No snackbar here – only Export button shows one
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ Helpers ------------------
  Color _colorForIndex(int i) {
    const palette = [
      Color(0xFF18D948),
      Color(0xFF0A84FF),
      Color(0xFFFFA726),
      Color(0xFFAB47BC),
      Color(0xFF26C6DA),
      Color(0xFFFF7043),
    ];
    return palette[i % palette.length];
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.bodyText.copyWith(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    if (!_dataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data is still loading, please wait...')),
      );
      return;
    }

    try {
      final csvString = _buildCsvExport();

      if (kIsWeb) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        downloadCsvFile(
          content: csvString,
          fileName: 'aidlink_analytics_$timestamp.csv',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV downloaded successfully.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin CSV export is available on web.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportHtmlReport() async {
    if (!_dataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data is still loading, please wait...')),
      );
      return;
    }

    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin report export is available on web.'),
        ),
      );
      return;
    }

    try {
      final htmlReport = _buildHtmlReport();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      downloadTextFile(
        content: htmlReport,
        fileName: 'aidlink_analytics_report_$timestamp.html',
        mimeType: 'text/html;charset=utf-8',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HTML report downloaded successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report export failed: ${e.toString()}')),
        );
      }
    }
  }

  String _csvCell(dynamic value) {
    final raw = value?.toString() ?? '';
    final escaped = raw.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildCsvExport() {
    final generatedAt = DateTime.now().toIso8601String();
    final monthlyTotal = monthlyAppointments.values.fold<int>(
      0,
      (a, b) => a + b,
    );

    final buffer = StringBuffer();
    buffer.writeln(
      '${_csvCell('AidLink Analytics Export')},${_csvCell(generatedAt)}',
    );
    buffer.writeln('${_csvCell('Selected Range')},${_csvCell(_selectedRange)}');
    buffer.writeln();

    buffer.writeln(_csvCell('SUMMARY'));
    buffer.writeln('${_csvCell('Metric')},${_csvCell('Value')}');
    buffer.writeln(
      '${_csvCell('Total Appointments')},${_csvCell(_totalAppointments)}',
    );
    buffer.writeln('${_csvCell('Total Patients')},${_csvCell(_totalPatients)}');
    buffer.writeln('${_csvCell('Total Doctors')},${_csvCell(_totalDoctors)}');
    buffer.writeln(
      '${_csvCell('Pending Approvals')},${_csvCell(_pendingApprovals)}',
    );
    buffer.writeln(
      '${_csvCell('Completed Appointments')},${_csvCell(_completedAppointments)}',
    );
    buffer.writeln(
      '${_csvCell('Total Prescriptions')},${_csvCell(_totalPrescriptions)}',
    );
    buffer.writeln();

    buffer.writeln(_csvCell('MONTHLY APPOINTMENTS'));
    buffer.writeln(
      '${_csvCell('Month')},${_csvCell('Count')},${_csvCell('Share %')}',
    );
    monthlyAppointments.forEach((month, count) {
      final share = monthlyTotal == 0 ? 0 : (count / monthlyTotal) * 100;
      buffer.writeln(
        '${_csvCell(month)},${_csvCell(count)},${_csvCell(share.toStringAsFixed(1))}',
      );
    });
    buffer.writeln();

    buffer.writeln(_csvCell('SPECIALTY DISTRIBUTION'));
    buffer.writeln('${_csvCell('Specialization')},${_csvCell('Percent')}');
    specialtyDistribution.forEach((spec, pct) {
      buffer.writeln('${_csvCell(spec)},${_csvCell(pct.toStringAsFixed(1))}');
    });
    buffer.writeln();

    buffer.writeln(_csvCell('WEEKLY ACTIVITY'));
    buffer.writeln('${_csvCell('Day')},${_csvCell('Active Users')}');
    for (int i = 0; i < activeUsersSpots.length; i++) {
      final dayLabel = 'Day ${i + 1}';
      final value = activeUsersSpots[i].y.toInt();
      buffer.writeln('${_csvCell(dayLabel)},${_csvCell(value)}');
    }

    return buffer.toString();
  }

  String _buildHtmlReport() {
    final monthlyLabels = monthlyAppointments.keys.toList();
    final monthlyValues = monthlyAppointments.values.toList();
    final specialtyLabels = specialtyDistribution.keys.toList();
    final specialtyValues = specialtyDistribution.values
        .map((v) => double.parse(v.toStringAsFixed(1)))
        .toList();
    final weeklyLabels = List.generate(
      activeUsersSpots.length,
      (i) => 'Day ${i + 1}',
    );
    final weeklyValues = activeUsersSpots.map((e) => e.y.toInt()).toList();

    final jsMonthlyLabels = jsonEncode(monthlyLabels);
    final jsMonthlyValues = jsonEncode(monthlyValues);
    final jsSpecialtyLabels = jsonEncode(specialtyLabels);
    final jsSpecialtyValues = jsonEncode(specialtyValues);
    final jsWeeklyLabels = jsonEncode(weeklyLabels);
    final jsWeeklyValues = jsonEncode(weeklyValues);

    return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>AidLink Analytics Report</title>
  <style>
    :root {
      --brand: #256d38;
      --bg: #f4f7f5;
      --card: #ffffff;
      --text: #1f2937;
      --muted: #6b7280;
      --border: #e5e7eb;
    }
    body {
      margin: 0;
      background: linear-gradient(160deg, #eef7f0 0%, var(--bg) 45%, #f7faf8 100%);
      color: var(--text);
      font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    }
    .wrap { max-width: 1200px; margin: 0 auto; padding: 24px; }
    .header {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 18px 20px;
      box-shadow: 0 8px 20px rgba(0,0,0,0.05);
      margin-bottom: 16px;
    }
    h1 { margin: 0; color: var(--brand); }
    .sub { color: var(--muted); margin-top: 6px; }
    .kpis {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
      gap: 12px;
      margin-bottom: 16px;
    }
    .kpi {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 12px;
    }
    .kpi .label { color: var(--muted); font-size: 12px; }
    .kpi .value { color: var(--brand); font-size: 24px; font-weight: 700; margin-top: 4px; }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
      gap: 14px;
    }
    .card {
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 14px;
      box-shadow: 0 8px 18px rgba(0,0,0,0.04);
    }
    .card h3 { margin: 0 0 8px 0; color: var(--brand); }
    .foot { margin-top: 14px; color: var(--muted); font-size: 12px; }
    canvas { width: 100% !important; height: 280px !important; }
  </style>
</head>
<body>
  <div class="wrap">
    <div class="header">
      <h1>AidLink Analytics Report</h1>
      <div class="sub">Generated at: ${DateTime.now().toString().split('.').first} | Range: $_selectedRange</div>
    </div>

    <div class="kpis">
      <div class="kpi"><div class="label">Total Appointments</div><div class="value">$_totalAppointments</div></div>
      <div class="kpi"><div class="label">Total Patients</div><div class="value">$_totalPatients</div></div>
      <div class="kpi"><div class="label">Total Doctors</div><div class="value">$_totalDoctors</div></div>
      <div class="kpi"><div class="label">Pending Approvals</div><div class="value">$_pendingApprovals</div></div>
      <div class="kpi"><div class="label">Completed Appointments</div><div class="value">$_completedAppointments</div></div>
      <div class="kpi"><div class="label">Prescriptions</div><div class="value">$_totalPrescriptions</div></div>
    </div>

    <div class="grid">
      <div class="card">
        <h3>Monthly Appointments</h3>
        <canvas id="monthlyChart"></canvas>
      </div>
      <div class="card">
        <h3>Specialty Distribution (%)</h3>
        <canvas id="specialtyChart"></canvas>
      </div>
      <div class="card" style="grid-column: 1 / -1;">
        <h3>Weekly Active Users</h3>
        <canvas id="weeklyChart"></canvas>
      </div>
    </div>

    <div class="foot">Tip: this HTML report keeps visuals. Use Export CSV for spreadsheet workflows.</div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <script>
    const monthlyLabels = $jsMonthlyLabels;
    const monthlyValues = $jsMonthlyValues;
    const specialtyLabels = $jsSpecialtyLabels;
    const specialtyValues = $jsSpecialtyValues;
    const weeklyLabels = $jsWeeklyLabels;
    const weeklyValues = $jsWeeklyValues;

    new Chart(document.getElementById('monthlyChart'), {
      type: 'bar',
      data: {
        labels: monthlyLabels,
        datasets: [{
          label: 'Appointments',
          data: monthlyValues,
          backgroundColor: 'rgba(37,109,56,0.75)',
          borderRadius: 8,
        }]
      },
      options: { responsive: true, plugins: { legend: { display: false } } }
    });

    new Chart(document.getElementById('specialtyChart'), {
      type: 'doughnut',
      data: {
        labels: specialtyLabels,
        datasets: [{
          data: specialtyValues,
          backgroundColor: ['#256d38', '#0A84FF', '#FFA726', '#AB47BC', '#26C6DA', '#FF7043'],
        }]
      },
      options: { responsive: true, plugins: { legend: { position: 'bottom' } } }
    });

    new Chart(document.getElementById('weeklyChart'), {
      type: 'line',
      data: {
        labels: weeklyLabels,
        datasets: [{
          label: 'Active Users',
          data: weeklyValues,
          borderColor: '#256d38',
          backgroundColor: 'rgba(37,109,56,0.15)',
          fill: true,
          tension: 0.35,
          pointRadius: 3,
        }]
      },
      options: { responsive: true }
    });
  </script>
</body>
</html>
''';
  }
}
