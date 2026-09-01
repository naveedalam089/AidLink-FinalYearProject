import 'dart:convert';

import 'package:flutter/material.dart';
// Purpose: Doctor web dashboard (sections for appointments, schedule, prescriptions, chats).
// File: lib/views/doctor_web/dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/app_values.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/services/doctor_duty_service.dart';
import 'sections/dashboard_overview.dart';
import 'sections/appointments_section.dart';
import 'sections/chat_section.dart';
import 'sections/upcoming_appointments_section.dart';
import 'sections/update_schedule_section.dart';
import 'sections/pending_requests_section.dart';
import 'sections/write_prescription_section.dart';
import '../doctor_mobile/patient_prescription_history_screen.dart';

class DashboardScreenWeb extends StatefulWidget {
  const DashboardScreenWeb({Key? key}) : super(key: key);

  @override
  State<DashboardScreenWeb> createState() => _DashboardScreenWebState();
}

class _DashboardScreenWebState extends State<DashboardScreenWeb> {
  final User? _user = FirebaseAuth.instance.currentUser;
  int selectedIndex = 0;
  int _dashboardSubIndex = -1; // -1 means show overview

  /// Tracks the previous dashboard sub-index so we can return the user to the
  /// correct view when they press "Back" (for example: from History back to
  /// Upcoming Appointments).
  int _previousDashboardSubIndex = -1;

  String _selectedPatient = '';
  String selectedPatientId = '';
  String selectedAppointmentId = '';
  bool _profileSheetOpen = false;
  String _chatSearchQuery = '';

  // --- Helper: Parse image from base64, network, or asset ---
  ImageProvider _profileImageProvider(String? rawValue) {
    final value = (rawValue ?? '').toString().trim();

    if (value.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(value.split(',').last));
      } catch (_) {
        return const AssetImage('assets/images/default_profile.jpg');
      }
    }

    if (value.isNotEmpty) {
      return NetworkImage(value);
    }

    return const AssetImage('assets/images/default_profile.jpg');
  }

  @override
  Widget build(BuildContext context) {
    // --- Build doctor web dashboard shell and section navigation ---
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Doctor Dashboard',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                if (_user != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection(FirestoreCollections.notifications)
                        .where(
                          NotificationFields.recipientId,
                          isEqualTo: _user!.uid,
                        )
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? const [];
                      final count = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return (data[NotificationFields.isRead] ?? false) !=
                            true;
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
            onPressed: () => Navigator.pushNamed(context, '/notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _showProfileSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryGreen,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: MediaQuery.of(context).size.width <= 1000 ? _buildDrawer() : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 1000;

          return Row(
            children: [
              if (isWide) _buildNavigationRail(),
              if (isWide)
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                  color: AppColors.borderGray,
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SingleChildScrollView(
                    child: _buildContent(selectedIndex),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sidebar for wide screens

  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: AppColors.backgroundWhite,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        if (index == 3) {
          // ✅ Go Off Duty
          _goOffDuty();
        } else if (index == 4) {
          // ✅ Logout logic
          FirebaseAuth.instance.signOut().then((_) {
            if (!mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          });
        } else {
          setState(() {
            selectedIndex = index;
            _dashboardSubIndex = -1; // Reset sub-index when switching main tabs
          });
        }
      },
      labelType: NavigationRailLabelType.all,
      destinations: [
        _navItem(Icons.dashboard, 'Dashboard'),
        _navItem(Icons.calendar_today, 'Appointments'),
        _navItem(Icons.chat, 'Chat'),

        // ✅ Go Off Duty as second to last item
        NavigationRailDestination(
          icon: const Icon(Icons.power_settings_new, color: Colors.red),
          label: const Text('Off Duty', style: TextStyle(color: Colors.red)),
        ),

        // ✅ Logout as last item
        NavigationRailDestination(
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  NavigationRailDestination _navItem(IconData icon, String label) {
    return NavigationRailDestination(
      icon: label == 'Chat' && _user != null
          ? _buildChatIconWithUnreadBadge(_user!.uid)
          : Icon(icon, color: AppColors.primaryGreen),
      label: Text(label, style: AppTypography.bodyText),
    );
  }

  /// Drawer for small screens
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: AppColors.primaryGreen,
        child: ListView(
          children: [
            const DrawerHeader(
              child: Text('Menu', style: TextStyle(color: Colors.white)),
            ),
            _drawerItem(Icons.dashboard, 'Dashboard', 0),
            _drawerItem(Icons.calendar_today, 'Appointments', 1),
            _drawerItem(Icons.chat, 'Chat', 2),

            const Divider(color: Colors.white70),

            // ✅ Go Off Duty button with depth
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.power_settings_new,
                  color: Colors.red,
                ),
                title: const Text(
                  'Go Off Duty',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goOffDuty();
                },
              ),
            ),

            // ✅ Logout button with depth
            Card(
              elevation: 4,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadProfileData() async {
    if (_user == null) return {};

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user!.uid)
        .get();
    final doctorSnap = await FirebaseFirestore.instance
        .collection('doctors')
        .doc(_user!.uid)
        .get();

    final userData = userSnap.data() as Map<String, dynamic>? ?? {};
    final doctorData = doctorSnap.data() as Map<String, dynamic>? ?? {};

    return {
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'email': userData['email'] ?? '',
      'specialization':
          doctorData['specialization'] ?? userData['specialization'] ?? '',
      'qualification': doctorData['qualification'] ?? '',
      'experience': doctorData['experience'] ?? '',
      'hospital': doctorData['hospital'] ?? '',
      'phone': doctorData['phone'] ?? '',
      'status': doctorData['status'] ?? 'pending',
      'profilePhotoUrl':
          doctorData['profilePhotoUrl'] ?? userData['profilePhotoUrl'],
    };
  }

  Future<void> _goOffDuty() async {
    if (_user == null) return;

    final doctorName = await _getDoctorName();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 32),
        title: const Text('Go Off Duty'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action will:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text('• Cancel all remaining appointments for today'),
            const Text('• Decline all pending postponed offers'),
            const Text('• Notify all affected patients'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Go Off Duty'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    final loadingDialog = _buildLoadingDialog('Going off duty...');
    showDialog(context: context, builder: (_) => loadingDialog);

    try {
      final result = await DoctorDutyService.goOffDuty(
        doctorId: _user!.uid,
        doctorName: doctorName,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are now off duty. Cancelled ${result['cancelledCount']} appointments, '
            'declined ${result['declinedCount']} offers, notified ${result['affectedPatientCount']} patients.',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> _getDoctorName() async {
    if (_user == null) return 'Doctor';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(_user!.uid)
          .get();
      final data = userDoc.data() ?? <String, dynamic>{};
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      return '$firstName $lastName'.trim();
    } catch (_) {
      return 'Doctor';
    }
  }

  Widget _buildLoadingDialog(String message) {
    return AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  void _showProfileSheet() {
    if (_profileSheetOpen || _user == null) return;

    _profileSheetOpen = true;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.62,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: _loadProfileData(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Failed to load profile: ${snapshot.error}',
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final data = snapshot.data!;
                  final fullName =
                      '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
                          .trim();
                  final photoUrl = data['profilePhotoUrl']?.toString() ?? '';
                  final status = (data['status'] ?? 'pending').toString();

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.borderGray,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF256D38), Color(0xFF1B4F2A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.white,
                              backgroundImage: _profileImageProvider(photoUrl),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              fullName.isEmpty ? 'Doctor' : fullName,
                              style: AppTypography.heading2.copyWith(
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              data['specialization']?.toString().isNotEmpty ==
                                      true
                                  ? data['specialization'].toString()
                                  : 'Doctor',
                              style: AppTypography.bodyText.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _profileInfoCard(data, status),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                Navigator.pushNamed(
                                  context,
                                  '/doctor-edit-profile-web',
                                ).then((_) {
                                  if (mounted) setState(() {});
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetContext);
                              },
                              icon: const Icon(Icons.close),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textDark,
                                side: const BorderSide(
                                  color: AppColors.borderGray,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _profileSheetOpen = false;
    });
  }

  Widget _profileInfoCard(Map<String, dynamic> data, String status) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _profileTile(Icons.email_outlined, 'Email', data['email'] ?? '-'),
          _profileTile(Icons.phone_outlined, 'Phone', data['phone'] ?? '-'),
          _profileTile(
            Icons.medical_services_outlined,
            'Specialization',
            data['specialization'] ?? '-',
          ),
          _profileTile(
            Icons.workspace_premium_outlined,
            'Qualification',
            data['qualification'] ?? '-',
          ),
          _profileTile(
            Icons.timelapse_outlined,
            'Experience',
            data['experience'] ?? '-',
          ),
          _profileTile(
            Icons.local_hospital_outlined,
            'Hospital',
            data['hospital'] ?? '-',
          ),
          _profileTile(Icons.verified_outlined, 'Status', status.toUpperCase()),
        ],
      ),
    );
  }

  Widget _profileTile(IconData icon, String label, dynamic value) {
    final text = value?.toString().isNotEmpty == true ? value.toString() : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: AppTypography.bodyText.copyWith(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Drawer Item with depth
  Widget _drawerItem(IconData icon, String title, int index) {
    return Card(
      elevation: 4, // Adds shadow for depth
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ListTile(
        leading: title == 'Chat' && _user != null
            ? _buildChatIconWithUnreadBadge(_user!.uid)
            : Icon(icon, color: AppColors.primaryGreen),
        title: Text(title, style: const TextStyle(color: AppColors.textDark)),
        onTap: () {
          Navigator.pop(context);
          setState(() {
            selectedIndex = index;
            _dashboardSubIndex = -1; // Reset sub-index
          });
        },
      ),
    );
  }

  Widget _buildChatIconWithUnreadBadge(String uid) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat, color: AppColors.primaryGreen),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rooms')
              .where('participants', arrayContains: uid)
              .snapshots(),
          builder: (context, snapshot) {
            final total = (snapshot.data?.docs ?? const []).fold<int>(0, (
              sum,
              doc,
            ) {
              final data = doc.data() as Map<String, dynamic>;
              final unreadCounts = Map<String, dynamic>.from(
                data['unreadCounts'] ?? {},
              );
              final count = unreadCounts[uid];
              return sum + (count is num ? count.toInt() : 0);
            });

            if (total <= 0) return const SizedBox.shrink();

            return Positioned(
              right: -8,
              top: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: total > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: total > 9 ? BorderRadius.circular(9) : null,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    total > 99 ? '99+' : '$total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Dynamic content based on selectedIndex
  Widget _buildContent(int index) {
    switch (index) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return AppointmentsSection(
          onChatOpen: (patientId, appointmentId, patientName) {
            setState(() {
              selectedIndex = 2; // Switch to Chat section
              selectedPatientId = patientId;
              selectedAppointmentId = appointmentId;
              _selectedPatient = patientName;
            });
          },
        );
      case 2:
        return _buildDoctorWebChatPanel();
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            WritePrescriptionSection(
              patientId: selectedPatientId,
              appointmentId: selectedAppointmentId,
            ),
          ],
        );
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDoctorWebChatPanel() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF5F5F5),
      ),
      child: Row(
        children: [
          SizedBox(width: 280, child: _buildChatPatientList()),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: selectedPatientId.isEmpty
                ? _buildChatEmptyPane()
                : ChatSection(
                    patientId: selectedPatientId,
                    patientName: _selectedPatient.isEmpty
                        ? 'Select a patient'
                        : _selectedPatient,
                    appointmentId: selectedAppointmentId.isEmpty
                        ? null
                        : selectedAppointmentId,
                    onClose: () => setState(() {
                      selectedPatientId = '';
                      _selectedPatient = '';
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPatientList() {
    return Container(
      color: const Color(0xFFF0F7F0),
      child: Column(
        children: [
          Container(
            height: 56,
            color: AppColors.primaryGreen,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Messages',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search patients',
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryGreen),
                ),
              ),
              onChanged: (value) => setState(() {
                _chatSearchQuery = value.toLowerCase();
              }),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .where('participants', arrayContains: _user?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  print('WEB ROOMS QUERY ERROR: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rooms =
                    (snapshot.data?.docs ?? const [])
                        .where((doc) => doc.data() is Map<String, dynamic>)
                        .toList()
                      ..sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;
                        final aAt = aData['lastAt'] as Timestamp?;
                        final bAt = bData['lastAt'] as Timestamp?;
                        if (aAt == null && bAt == null) return 0;
                        if (aAt == null) return 1;
                        if (bAt == null) return -1;
                        return bAt.toDate().compareTo(aAt.toDate());
                      });

                final activeRooms = rooms.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  // Show room if it has ever had a message — checked via participants and any message-related field
                  final hasLastSenderId = (data['lastSenderId'] ?? '')
                      .toString()
                      .isNotEmpty;
                  final hasLastMessage = (data['lastMessage'] ?? '')
                      .toString()
                      .isNotEmpty;
                  final hasUnreadCounts =
                      (data['unreadCounts'] as Map?)?.isNotEmpty ?? false;
                  return hasLastSenderId || hasLastMessage || hasUnreadCounts;
                }).toList();

                if (activeRooms.isEmpty) {
                  return const Center(child: Text('No conversations yet'));
                }

                return ListView.builder(
                  itemCount: activeRooms.length,
                  itemBuilder: (context, index) {
                    final roomData =
                        activeRooms[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(
                      roomData['participants'] ?? [],
                    );
                    final patientId = participants.firstWhere(
                      (id) => id != _user?.uid,
                      orElse: () => '',
                    );
                    if (patientId.isEmpty) return const SizedBox.shrink();

                    return FutureBuilder<Map<String, dynamic>>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(patientId)
                          .get()
                          .then((doc) {
                            if (!doc.exists) {
                              return {'name': 'Patient', 'photoUrl': ''};
                            }
                            final d = doc.data() as Map<String, dynamic>;
                            final fn = (d['firstName'] ?? '').toString();
                            final ln = (d['lastName'] ?? '').toString();
                            final full = '$fn $ln'.trim();
                            return {
                              'name': full.isNotEmpty ? full : 'Patient',
                              'photoUrl': (d['profilePhotoUrl'] ?? '')
                                  .toString(),
                            };
                          })
                          .timeout(
                            const Duration(seconds: 5),
                            onTimeout: () => {
                              'name': 'Patient',
                              'photoUrl': '',
                            },
                          ),
                      builder: (context, userSnap) {
                        final info =
                            userSnap.data ??
                            {'name': 'Patient', 'photoUrl': ''};
                        final patientName = info['name'] as String;
                        final photoUrl = info['photoUrl'] as String;
                        final isSelected = selectedPatientId == patientId;
                        final query = _chatSearchQuery.trim();
                        if (query.isNotEmpty &&
                            !patientName.toLowerCase().contains(query)) {
                          return const SizedBox.shrink();
                        }

                        final unreadCounts = Map<String, dynamic>.from(
                          roomData['unreadCounts'] ?? {},
                        );
                        final unreadCount = unreadCounts[_user?.uid] ?? 0;
                        final hasUnread = unreadCount > 0;
                        final lastMessage = (roomData['lastMessage'] ?? '')
                            .toString();
                        final lastAt = roomData['lastAt'] as Timestamp?;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFDCEEDC)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? const Border(
                                    left: BorderSide(
                                      color: AppColors.primaryGreen,
                                      width: 3,
                                    ),
                                  )
                                : const Border(
                                    bottom: BorderSide(
                                      color: Color(0xFFEEEEEE),
                                      width: 0.5,
                                    ),
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(() {
                              selectedPatientId = patientId;
                              selectedAppointmentId =
                                  (roomData['appointmentId'] ?? '').toString();
                              _selectedPatient = patientName;
                            }),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.primaryGreen,
                                  backgroundImage: photoUrl.isNotEmpty
                                      ? NetworkImage(photoUrl)
                                      : null,
                                  child: photoUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              patientName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            lastAt == null
                                                ? ''
                                                : '${lastAt.toDate().hour.toString().padLeft(2, '0')}:${lastAt.toDate().minute.toString().padLeft(2, '0')}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: hasUnread
                                                  ? AppColors.primaryGreen
                                                  : Colors.grey[500],
                                              fontWeight: hasUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lastMessage,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEmptyPane() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined, size: 72, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'Your Conversations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a patient from the left to start chatting.',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  /// Dashboard sub-content logic
  Widget _buildDashboardContent() {
    switch (_dashboardSubIndex) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            UpcomingAppointmentsSection(
              onWritePrescription: (patientId, appointmentId) {
                setState(() {
                  selectedIndex = 0; // ensure dashboard tab
                  selectedPatientId = patientId;
                  selectedAppointmentId = appointmentId;
                  _dashboardSubIndex = 3; // open prescription section
                });
              },
              onViewHistory: (patientId, patientName) {
                setState(() {
                  selectedIndex = 0;
                  _previousDashboardSubIndex =
                      0; // Remember we came from upcoming appointments
                  selectedPatientId = patientId;
                  _selectedPatient = patientName;
                  _dashboardSubIndex = 4; // open history section
                });
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_backButton(), const UpdateScheduleSection()],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            PendingRequestsSection(
              onChatOpen: (patientName) {
                setState(() {
                  selectedIndex = 2;
                  _selectedPatient = patientName;
                });
              },
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            WritePrescriptionSection(
              patientId: selectedPatientId,
              appointmentId: selectedAppointmentId,
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _backButton(),
            PatientPrescriptionHistoryScreen(
              patientId: selectedPatientId,
              patientName: _selectedPatient,
              showAppBar: false,
            ),
          ],
        );
      default:
        return DashboardOverview(
          onCardTap: (subIndex) {
            setState(() {
              _dashboardSubIndex = subIndex;
            });
          },
        );
    }
  }

  Widget _backButton() {
    // If the current view is the prescription history, the back button
    // should return to the previous sub-view (typically Upcoming Appointments).
    final isFromHistory = _dashboardSubIndex == 4;
    final backLabel = isFromHistory
        ? 'Back to Appointments'
        : 'Back to Overview';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ElevatedButton.icon(
        onPressed: () {
          setState(() {
            if (isFromHistory) {
              // Navigate back to the previously recorded sub-index (not overview)
              _dashboardSubIndex = _previousDashboardSubIndex;
            } else {
              _dashboardSubIndex = -1; // Go to overview
            }
          });
        },
        icon: const Icon(Icons.arrow_back),
        label: Text(backLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
