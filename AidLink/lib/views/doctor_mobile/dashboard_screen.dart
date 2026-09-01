import 'package:flutter/material.dart';
// Purpose: Doctor mobile dashboard (appointment requests, upcoming, profile, off-duty actions).
// File: lib/views/doctor_mobile/dashboard_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/widgets/appointment_card.dart';
import '../../core/constants/app_values.dart';
import '../../core/services/appointment_lifecycle_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/doctor_duty_service.dart';
import '../../core/services/admin_activity_service.dart';
import 'patient_prescription_history_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

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
  void initState() {
    super.initState();
    // --- Setup tab controller for appointment tabs ---
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- Approve appointment and notify patient ---
  Future<void> approveAppointment(String appointmentId) async {
    if (!mounted) return;
    final loadingDialog = _buildLoadingDialog('Approving appointment...');
    showDialog(context: context, builder: (_) => loadingDialog);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final patientId = (data['patientId'] ?? '').toString();

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .update({'status': AppointmentStatus.approved});

      if (patientId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Appointment approved',
          body: 'Your doctor approved your appointment request.',
          type: 'appointment_approved',
          data: {'appointmentId': appointmentId},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Appointment approved',
        body: 'A doctor approved a patient appointment request.',
        type: 'appointment_status_changed_by_doctor',
        data: {
          'appointmentId': appointmentId,
          'doctorId': (data['doctorId'] ?? '').toString(),
          'patientId': patientId,
          'status': AppointmentStatus.approved,
        },
      );

      await AdminActivityService.log(
        action: 'appointment_approved',
        targetType: 'appointment',
        targetId: appointmentId,
        summary: 'Doctor approved appointment request from patient',
        metadata: {
          'doctorId': user?.uid,
          'patientId': patientId,
          'appointmentDate': data['appointmentDate']?.toString(),
        },
        actorId: user?.uid,
        actorRole: UserRoles.doctor,
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment approved.')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> rejectAppointment(String appointmentId) async {
    if (!mounted) return;
    final loadingDialog = _buildLoadingDialog('Rejecting appointment...');
    showDialog(context: context, builder: (_) => loadingDialog);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final patientId = (data['patientId'] ?? '').toString();

      await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .update({'status': AppointmentStatus.rejected});

      if (patientId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Appointment rejected',
          body: 'Your appointment request was rejected.',
          type: 'appointment_rejected',
          data: {'appointmentId': appointmentId},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Appointment rejected',
        body: 'A doctor rejected a patient appointment request.',
        type: 'appointment_status_changed_by_doctor',
        data: {
          'appointmentId': appointmentId,
          'doctorId': (data['doctorId'] ?? '').toString(),
          'patientId': patientId,
          'status': AppointmentStatus.rejected,
        },
      );

      await AdminActivityService.log(
        action: 'appointment_rejected',
        targetType: 'appointment',
        targetId: appointmentId,
        summary: 'Doctor rejected appointment request from patient',
        metadata: {
          'doctorId': user?.uid,
          'patientId': patientId,
          'appointmentDate': data['appointmentDate']?.toString(),
        },
        actorId: user?.uid,
        actorRole: UserRoles.doctor,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Appointment rejected.')));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _completeAppointment(String appointmentId) async {
    if (!mounted) return;
    final loadingDialog = _buildLoadingDialog('Completing appointment...');
    showDialog(context: context, builder: (_) => loadingDialog);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final patientId = (data['patientId'] ?? '').toString();

      final actualMinutes = await _askActualDuration();
      if (actualMinutes == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final result = await AppointmentLifecycleService.markCompletedByDoctor(
        appointmentId: appointmentId,
        actualDurationMinutes: actualMinutes,
      );

      if (patientId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Appointment completed',
          body: result['recoveredMinutes'] > 0
              ? 'Your appointment was completed early.'
              : 'Your doctor marked the appointment as completed.',
          type: 'appointment_completed',
          data: {'appointmentId': appointmentId},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Appointment completed',
        body: 'A doctor marked an appointment as completed.',
        type: 'appointment_status_changed_by_doctor',
        data: {
          'appointmentId': appointmentId,
          'doctorId': (data['doctorId'] ?? '').toString(),
          'patientId': patientId,
          'status': AppointmentStatus.completed,
        },
      );

      await AdminActivityService.log(
        action: 'appointment_completed',
        targetType: 'appointment',
        targetId: appointmentId,
        summary: 'Doctor marked appointment as completed',
        metadata: {
          'doctorId': user?.uid,
          'patientId': patientId,
          'actualDuration': result['actualMinutes'],
          'recoveredMinutes': result['recoveredMinutes'],
        },
        actorId: user?.uid,
        actorRole: UserRoles.doctor,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['recoveredMinutes'] > 0
                ? 'Completed. Recovered ${result['recoveredMinutes']} min.'
                : 'Appointment marked as completed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _markNoShow(String appointmentId) async {
    if (!mounted) return;
    final loadingDialog = _buildLoadingDialog('Marking no-show...');
    showDialog(context: context, builder: (_) => loadingDialog);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .doc(appointmentId)
          .get();
      final data = snapshot.data() ?? <String, dynamic>{};
      final patientId = (data['patientId'] ?? '').toString();

      await AppointmentLifecycleService.markNoShow(
        appointmentId: appointmentId,
      );

      if (patientId.isNotEmpty) {
        await NotificationService.createNotification(
          recipientId: patientId,
          recipientRole: UserRoles.patient,
          title: 'Marked as no-show',
          body: 'The doctor marked this appointment as no-show.',
          type: 'appointment_no_show',
          data: {'appointmentId': appointmentId},
        );
      }

      await NotificationService.notifyAdmins(
        title: 'Appointment marked no-show',
        body: 'A doctor marked a patient appointment as no-show.',
        type: 'appointment_status_changed_by_doctor',
        data: {
          'appointmentId': appointmentId,
          'doctorId': (data['doctorId'] ?? '').toString(),
          'patientId': patientId,
          'status': AppointmentStatus.noShow,
        },
      );

      await AdminActivityService.log(
        action: 'appointment_no_show',
        targetType: 'appointment',
        targetId: appointmentId,
        summary: 'Doctor marked appointment as no-show',
        metadata: {'doctorId': user?.uid, 'patientId': patientId},
        actorId: user?.uid,
        actorRole: UserRoles.doctor,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment marked as no-show.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<int?> _askActualDuration() async {
    final controller = TextEditingController(text: '30');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actual Consultation Time'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Minutes'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _goOffDuty() async {
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
        doctorId: user!.uid,
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
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(user!.uid)
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

  void _openChatForPatient(String patientId, String patientName) {
    // Navigate to 1:1 chat screen with patient
    // Chat is available only after appointment is accepted
    Navigator.pushNamed(
      context,
      '/doctor-chat',
      arguments: {'patientId': patientId, 'patientName': patientName},
    );
  }

  void _openChatList() {
    Navigator.pushNamed(context, '/doctor-chats');
  }

  void _openPatientHistory(String patientId, String patientName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientPrescriptionHistoryScreen(
          patientId: patientId,
          patientName: patientName,
        ),
      ),
    );
  }

  /// Open the patient's prescription history as a full-screen route.
  ///
  /// This is used on mobile where a separate page is the expected UX. The
  /// `PatientPrescriptionHistoryScreen` will show its own AppBar and allow the
  /// user to navigate back using the system/back arrow.

  // ─────────────────────────────────────────────
  // DRAWER — real Firestore data
  // ─────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      child: FutureBuilder<List<DocumentSnapshot>>(
        future: Future.wait([
          FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(user!.uid)
              .get(),
          FirebaseFirestore.instance
              .collection(FirestoreCollections.doctors)
              .doc(user!.uid)
              .get(),
        ]),
        builder: (context, snapshot) {
          final u = snapshot.hasData
              ? (snapshot.data![0].data() as Map<String, dynamic>? ?? {})
              : <String, dynamic>{};
          final d = snapshot.hasData
              ? (snapshot.data![1].data() as Map<String, dynamic>? ?? {})
              : <String, dynamic>{};

          final firstName = u['firstName'] ?? '';
          final lastName = u['lastName'] ?? '';
          final email = u['email'] ?? '';
          final photoUrl = d['profilePhotoUrl'] ?? u['profilePhotoUrl'];
          final specialization =
              d['specialization'] ?? u['specialization'] ?? 'Doctor';
          final status = d['status'] ?? DoctorStatus.pending;

          return Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: AppColors.primaryGreen),
                currentAccountPicture: CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  backgroundImage: _profileImageProvider(photoUrl?.toString()),
                ),
                accountName: Text(
                  'Dr. $firstName $lastName',
                  style: AppTypography.heading3.copyWith(color: Colors.white),
                ),
                accountEmail: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          specialization,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusColor(status)),
                          ),
                          child: Text(
                            status.toString().toUpperCase(),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Menu items ───────────────────────────────────────────
              _drawerItem(
                Icons.dashboard,
                'Dashboard',
                () => Navigator.pop(context),
              ),

              _drawerItem(Icons.calendar_today, 'Appointments', () {
                Navigator.pop(context);
                _tabController.animateTo(0);
              }),

              _drawerItem(Icons.event_available, 'Upcoming', () {
                Navigator.pop(context);
                _tabController.animateTo(1);
              }),

              _drawerItem(
                Icons.chat_bubble_outline,
                'Chats',
                () {
                  Navigator.pop(context);
                  _openChatList();
                },
                leading: _buildChatIconWithUnreadBadge(user!.uid),
              ),

              _drawerItem(
                Icons.notifications_none,
                'Notifications',
                () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notifications');
                },
                trailing: _notificationBadge(user!.uid),
              ),

              _drawerItem(Icons.person_outline, 'My Profile', () {
                Navigator.pop(context);
                _tabController.animateTo(2);
              }),

              _drawerItem(Icons.edit, 'Edit Profile', () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/doctor-edit-profile',
                ).then((_) => setState(() {}));
              }),

              const Spacer(),

              const Divider(),

              // ── Go Off Duty ──────────────────────────────────────────
              ListTile(
                leading: const Icon(
                  Icons.power_settings_new,
                  color: Colors.red,
                ),
                title: const Text(
                  'Go Off Duty',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _goOffDuty();
                },
              ),

              // ── Logout ───────────────────────────────────────────────
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
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
              const SizedBox(height: AppSpacing.sm),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case DoctorStatus.approved:
        return Colors.green;
      case DoctorStatus.rejected:
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Widget _notificationBadge(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .where(NotificationFields.recipientId, isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];
        final count = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data[NotificationFields.isRead] ?? false) != true;
        }).length;
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildAppBarNotificationBell(String uid) {
    return IconButton(
      onPressed: () => Navigator.pushNamed(context, '/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: Colors.white),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection(FirestoreCollections.notifications)
                .where(NotificationFields.recipientId, isEqualTo: uid)
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

  Widget _drawerItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
    Widget? leading,
  }) {
    return ListTile(
      leading: leading ?? Icon(icon, color: AppColors.primaryGreen),
      title: Text(title, style: AppTypography.bodyText),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildChatIconWithUnreadBadge(String uid) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chat_bubble_outline, color: AppColors.primaryGreen),
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

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'AidLink',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        actions: [_buildAppBarNotificationBell(user!.uid)],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Profile'),
          ],
        ),
      ),

      drawer: _buildDrawer(),

      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(),
          _buildUpcomingTab(),
          _buildProfileTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // TAB 1 — PENDING REQUESTS
  // ─────────────────────────────────────────────
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .where('doctorId', isEqualTo: user!.uid)
          .where('status', isEqualTo: AppointmentStatus.pending)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final upcoming = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateRaw = data['appointmentDate'] ?? data['date'] ?? '';
          final timeRaw =
              data['slot'] ?? data['time'] ?? data['appointmentTime'] ?? '';
          try {
            DateTime apptDate;
            if (dateRaw is Timestamp) {
              apptDate = dateRaw.toDate();
            } else {
              apptDate = DateTime.parse(dateRaw.toString());
            }
            if (timeRaw.toString().isNotEmpty) {
              final timeParts = timeRaw.toString().toUpperCase().split(' ');
              final hm = timeParts[0].split(':');
              int hour = int.parse(hm[0]);
              final int minute = hm.length > 1 ? int.parse(hm[1]) : 0;
              if (timeParts.length > 1 && timeParts[1] == 'PM' && hour != 12)
                hour += 12;
              if (timeParts.length > 1 && timeParts[1] == 'AM' && hour == 12)
                hour = 0;
              apptDate = DateTime(
                apptDate.year,
                apptDate.month,
                apptDate.day,
                hour,
                minute,
              );
            }
            return apptDate.isAfter(now);
          } catch (_) {
            return true;
          }
        }).toList();
        if (upcoming.isEmpty)
          return const Center(child: Text('No pending requests'));

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: upcoming.length,
          itemBuilder: (context, index) {
            final doc = upcoming[index];
            final data = doc.data() as Map<String, dynamic>;
            final Timestamp ts = data['appointmentDate'];
            final DateTime dateTime = ts.toDate();
            final patientId = data['patientId'];
            final slot = (data['slot'] as String?)?.trim() ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get(),
              builder: (context, patientSnap) {
                if (!patientSnap.hasData) return const SizedBox();
                final patient =
                    patientSnap.data!.data() as Map<String, dynamic>? ?? {};
                final patientName =
                    "${patient['firstName']} ${patient['lastName']}";
                final symptoms = (data['symptoms'] ?? "").toString().split(",");

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patientName, style: AppTypography.heading3),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          "Date: ${dateTime.day}/${dateTime.month}/${dateTime.year}",
                        ),
                        Text(
                          "Time: ${slot.isNotEmpty ? slot : TimeOfDay.fromDateTime(dateTime).format(context)}",
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: 8,
                          children: symptoms
                              .map((s) => Chip(label: Text(s.trim())))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => rejectAppointment(doc.id),
                              child: const Text(
                                'Reject',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ElevatedButton(
                              onPressed: () => approveAppointment(doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                              ),
                              child: const Text(
                                'Approve',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
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
    );
  }

  // ─────────────────────────────────────────────
  // TAB 2 — UPCOMING APPOINTMENTS
  // ─────────────────────────────────────────────
  Widget _buildUpcomingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(FirestoreCollections.appointments)
          .where('doctorId', isEqualTo: user!.uid)
          .where('status', isEqualTo: AppointmentStatus.approved)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        final now = DateTime.now();
        final upcomingFiltered = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateRaw = data['appointmentDate'];
          final timeRaw = (data['slot'] ?? '').toString();
          try {
            DateTime apptDate;
            if (dateRaw is Timestamp) {
              apptDate = dateRaw.toDate();
            } else {
              apptDate = DateTime.parse(dateRaw.toString());
            }
            if (timeRaw.toString().isNotEmpty) {
              final timeParts = timeRaw.toString().toUpperCase().split(' ');
              final hm = timeParts[0].split(':');
              int hour = int.parse(hm[0]);
              final int minute = hm.length > 1 ? int.parse(hm[1]) : 0;
              if (timeParts.length > 1 && timeParts[1] == 'PM' && hour != 12)
                hour += 12;
              if (timeParts.length > 1 && timeParts[1] == 'AM' && hour == 12)
                hour = 0;
              apptDate = DateTime(
                apptDate.year,
                apptDate.month,
                apptDate.day,
                hour,
                minute,
              );
            }
            return apptDate.isAfter(now);
          } catch (_) {
            return true;
          }
        }).toList();

        if (upcomingFiltered.isEmpty)
          return const Center(child: Text('No upcoming appointments'));

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: upcomingFiltered.length,
          itemBuilder: (context, index) {
            final data = upcomingFiltered[index].data() as Map<String, dynamic>;
            final Timestamp ts = data['appointmentDate'];
            final DateTime dateTime = ts.toDate();
            final patientId = data['patientId'];
            final slot = (data['slot'] as String?)?.trim() ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(patientId)
                  .get(),
              builder: (context, patientSnap) {
                if (!patientSnap.hasData) return const SizedBox();
                final patient =
                    patientSnap.data!.data() as Map<String, dynamic>? ?? {};
                final patientName =
                    "${patient['firstName']} ${patient['lastName']}";

                return Column(
                  children: [
                    AppointmentCard(
                      doctorName: patientName,
                      date:
                          "${dateTime.day}/${dateTime.month}/${dateTime.year}",
                      time: slot.isNotEmpty
                          ? slot
                          : TimeOfDay.fromDateTime(dateTime).format(context),
                      status: "Confirmed",
                      showAction: false,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _openPatientHistory(patientId, patientName),
                            icon: const Icon(
                              Icons.history_outlined,
                              color: Colors.blue,
                            ),
                            label: const Text(
                              'History',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _openChatForPatient(patientId, patientName),
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              color: AppColors.primaryGreen,
                            ),
                            label: const Text(
                              'Chat',
                              style: TextStyle(color: AppColors.primaryGreen),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                _completeAppointment(docs[index].id),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            label: const Text(
                              'Complete',
                              style: TextStyle(color: Colors.green),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _markNoShow(docs[index].id),
                            icon: const Icon(
                              Icons.person_off_outlined,
                              color: Colors.deepOrange,
                            ),
                            label: const Text(
                              'No-show',
                              style: TextStyle(color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // TAB 3 — PROFILE
  // ─────────────────────────────────────────────
  Widget _buildProfileTab() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user!.uid).get(),
        FirebaseFirestore.instance.collection('doctors').doc(user!.uid).get(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final u = snapshot.data![0].data() as Map<String, dynamic>? ?? {};
        final d = snapshot.data![1].data() as Map<String, dynamic>? ?? {};

        final firstName = u['firstName'] ?? '';
        final lastName = u['lastName'] ?? '';
        final email = u['email'] ?? '';
        final profilePhotoUrl = d['profilePhotoUrl'] ?? u['profilePhotoUrl'];
        final specialization =
            d['specialization'] ?? u['specialization'] ?? 'Not set';
        final qualification = d['qualification'] ?? 'Not set';
        final experience = d['experience'] ?? 'Not set';
        final hospital = d['hospital'] ?? u['hospital'] ?? 'Not set';
        final phone = d['phone'] ?? 'Not set';
        final address = d['address'] ?? 'Not set';
        final bio = d['bio'] ?? '';
        final status = d['status'] ?? 'pending';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),

              // Photo
              CircleAvatar(
                radius: 55,
                backgroundColor: AppColors.borderGray,
                backgroundImage: _profileImageProvider(
                  profilePhotoUrl?.toString(),
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              Text(
                'Dr. $firstName $lastName',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                specialization,
                style: AppTypography.bodyText.copyWith(color: Colors.grey),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(status).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor(status)),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),

              // Bio
              if (bio.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  bio,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              // Contact info card
              _profileCard([
                _infoRow(Icons.email, 'Email', email),
                _infoRow(Icons.phone, 'Phone', phone),
                _infoRow(Icons.location_on, 'Address', address),
              ]),

              const SizedBox(height: AppSpacing.md),

              // Professional info card
              _profileCard([
                _infoRow(
                  Icons.medical_services,
                  'Specialization',
                  specialization,
                ),
                _infoRow(Icons.school, 'Qualification', qualification),
                _infoRow(Icons.work, 'Experience', '$experience years'),
                _infoRow(Icons.local_hospital, 'Hospital', hospital),
              ]),

              const SizedBox(height: AppSpacing.lg),

              // Edit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/doctor-edit-profile');
                    setState(() {});
                  },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileCard(List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(children: rows),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.bodyText.copyWith(
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
}
