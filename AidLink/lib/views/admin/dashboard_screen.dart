import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Purpose: Main admin dashboard navigation (tabs for overview, appointments, doctors, support requests, analytics, activity logs, settings).
// File: lib/views/admin/dashboard_screen.dart

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/constants/app_values.dart';
import 'sections/dashboard_overview.dart';
import 'sections/doctors_section.dart';
import 'sections/patients_section.dart';
import 'sections/appointments_section.dart';
import 'sections/analytics_section.dart';
import 'sections/settings_section.dart';
import 'sections/feedback_section.dart';
import 'sections/activity_logs_section.dart';
import 'sections/support_requests_section.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialIndex;

  const AdminDashboardScreen({Key? key, this.initialIndex = 0})
    : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int selectedIndex = 0;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final maxIndex = menuItems.length - 2;
    selectedIndex = widget.initialIndex.clamp(0, maxIndex);
  }

  final List<String> menuItems = [
    'Dashboard',
    'Requests',
    'Patients',
    'Appointments',
    'Analytics',
    'Support Requests',
    'Feedback',
    'Settings',
    'Activity Logs',
    'Notifications',
  ];

  IconData _menuIcon(String item) {
    switch (item) {
      case 'Dashboard':
        return Icons.dashboard;
      case 'Requests':
        return Icons.verified_user;
      case 'Patients':
        return Icons.people;
      case 'Appointments':
        return Icons.calendar_today;
      case 'Analytics':
        return Icons.bar_chart;
      case 'Support Requests':
        return Icons.support_agent;
      case 'Feedback':
        return Icons.feedback;
      case 'Settings':
        return Icons.settings;
      case 'Notifications':
        return Icons.notifications_none;
      case 'Activity Logs':
        return Icons.history;
      default:
        return Icons.circle;
    }
  }

  Widget _getSection() {
    switch (selectedIndex) {
      case 0:
        return const DashboardOverview();
      case 1:
        return const DoctorsSection();
      case 2:
        return const PatientsSection();
      case 3:
        return const AppointmentsSection();
      case 4:
        return const AnalyticsSection();
      case 5:
        return const SupportRequestsSection();
      case 6:
        return const FeedbackSection();
      case 7:
        return const SettingsSection();
      case 8:
        return const ActivityLogsSection();
      default:
        return const DashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 600;
        bool isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primaryGreen,
            elevation: 0,
            title: const Text(
              'AidLink Admin',
              style: TextStyle(color: Colors.white),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [_buildNotificationBellButton()],
          ),
          drawer: isMobile
              ? Drawer(
                  child: Container(
                    color: AppColors.primaryGreen,
                    child: _buildSidebar(isCompact: false, isDrawer: true),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (!isMobile)
                Container(
                  width: isTablet ? 80 : 250,
                  color: AppColors.primaryGreen,
                  child: _buildSidebar(isCompact: isTablet, isDrawer: false),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: _getSection(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------- SIDEBAR + DRAWER -------------------
  Widget _buildSidebar({required bool isCompact, required bool isDrawer}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                if (!isCompact)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'AidLink',
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl),

                // Menu Items
                ...List.generate(menuItems.length, (index) {
                  bool isSelected = selectedIndex == index;
                  return InkWell(
                    onTap: () {
                      if (menuItems[index] == 'Notifications') {
                        Navigator.pushNamed(context, '/notifications');
                        if (isDrawer && Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        }
                        return;
                      }

                      setState(() => selectedIndex = index);
                      if (isDrawer && Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                        horizontal: AppSpacing.sm,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _menuIcon(menuItems[index]),
                            color: Colors.white,
                          ),
                          if (!isCompact) const SizedBox(width: 10),
                          if (!isCompact)
                            Text(
                              menuItems[index],
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          if (menuItems[index] == 'Notifications') ...[
                            const Spacer(),
                            _notificationsBadge(),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // ---------------- LOGOUT BUTTON (NEW) ----------------
        InkWell(
          onTap: () {
            FirebaseAuth.instance.signOut().then((_) {
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.sm,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.logout, color: Colors.red),
                if (!isCompact) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Logout',
                    style: AppTypography.bodyText.copyWith(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _notificationsBadge() {
    if (_user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .where(NotificationFields.recipientId, isEqualTo: _user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final count = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data[NotificationFields.isRead] ?? false) != true;
        }).length;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationBellButton() {
    if (_user == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () => Navigator.pushNamed(context, '/notifications'),
      );
    }

    return IconButton(
      onPressed: () => Navigator.pushNamed(context, '/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.notifications)
                .where(NotificationFields.recipientId, isEqualTo: _user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final count = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return (data[NotificationFields.isRead] ?? false) != true;
              }).length;
              if (count == 0) return const SizedBox.shrink();

              return Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
