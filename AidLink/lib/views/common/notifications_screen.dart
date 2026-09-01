import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
// Purpose: Notifications inbox for users (view, mark as read, delete notifications).
// File: lib/views/common/notifications_screen.dart

import 'package:flutter/material.dart';

import '../../core/constants/app_values.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/postponed_offer_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _didRunExpiry = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didRunExpiry) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      PostponedOfferService.expireStaleOffersForUser(user.uid);
    }

    _didRunExpiry = true;
  }

  // --- Pick icon based on notification type ---
  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment_approved':
        return Icons.check_circle;
      case 'appointment_rejected':
        return Icons.cancel;
      case 'appointment_completed':
        return Icons.task_alt;
      case 'appointment_cancelled':
      case 'appointment_cancelled_admin':
        return Icons.event_busy;
      case 'appointment_request':
      case 'appointment_request_sent':
      case 'admin_appointment_alert':
        return Icons.calendar_today;
      case 'postpone_offer':
      case 'postpone_offer_accepted':
      case 'postpone_offer_declined':
      case 'postpone_offer_expired':
        return Icons.schedule;
      case 'prescription_added':
        return Icons.description;
      default:
        return Icons.notifications;
    }
  }

  // --- Pick accent color based on notification type ---
  Color _colorForType(String type) {
    switch (type) {
      case 'appointment_approved':
      case 'appointment_completed':
      case 'prescription_added':
        return AppColors.primaryGreen;
      case 'appointment_rejected':
      case 'appointment_cancelled':
      case 'appointment_cancelled_admin':
        return Colors.red;
      case 'admin_appointment_alert':
      case 'appointment_request':
      case 'appointment_request_sent':
      case 'postpone_offer':
      case 'postpone_offer_accepted':
      case 'postpone_offer_declined':
      case 'postpone_offer_expired':
        return Colors.orange;
      default:
        return AppColors.primaryGreen;
    }
  }

  Future<void> _openPrescriptionDetail(
    BuildContext context,
    String prescriptionId,
  ) async {
    final prescriptionDoc = await FirebaseFirestore.instance
        .collection(FirestoreCollections.prescriptions)
        .doc(prescriptionId)
        .get();

    if (!prescriptionDoc.exists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prescription not found.')));
      return;
    }

    final p = prescriptionDoc.data() ?? <String, dynamic>{};
    final doctorId = (p['doctorId'] ?? '').toString();
    final patientId = (p['patientId'] ?? '').toString();

    final doctorSnap = doctorId.isEmpty
        ? null
        : await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(doctorId)
              .get();
    final patientSnap = patientId.isEmpty
        ? null
        : await FirebaseFirestore.instance
              .collection(FirestoreCollections.users)
              .doc(patientId)
              .get();

    final doctorData = doctorSnap?.data() ?? <String, dynamic>{};
    final patientData = patientSnap?.data() ?? <String, dynamic>{};

    final doctorFirst = (doctorData['firstName'] ?? '').toString().trim();
    final doctorLast = (doctorData['lastName'] ?? '').toString().trim();
    final doctorNameRaw = '$doctorFirst $doctorLast'.trim();
    final doctorName = doctorNameRaw.isEmpty ? 'Doctor' : 'Dr. $doctorNameRaw';
    final patientName =
        '${(patientData['firstName'] ?? '').toString()} ${(patientData['lastName'] ?? '').toString()}'
            .trim();

    if (!context.mounted) return;
    Navigator.pushNamed(
      context,
      '/prescription-detail',
      arguments: {
        'doctorName': doctorName.isEmpty ? 'Doctor' : doctorName,
        'patientName': patientName.isEmpty ? 'Patient' : patientName,
        'medicines': p['medicines'] is List
            ? List<dynamic>.from(p['medicines'])
            : <dynamic>[],
        'diagnosis': (p['diagnosis'] ?? '').toString(),
        'advice': (p['advice'] ?? '').toString(),
        'followUpDateText': p['followUpDate'] is Timestamp
            ? _formatDate((p['followUpDate'] as Timestamp).toDate())
            : null,
        'date': p['createdAt'] is Timestamp
            ? (p['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      },
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notification,
  ) async {
    final type = (notification[NotificationFields.type] ?? '').toString();
    final role = (notification[NotificationFields.recipientRole] ?? '')
        .toString();
    final rawData = notification[NotificationFields.data];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    // Mark as read first
    final notifId = (notification['id'] ?? '').toString();
    if (notifId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.notifications)
          .doc(notifId)
          .update({NotificationFields.isRead: true});
    }

    // ── Prescription ──────────────────────────────────────────────
    if (type == 'prescription_added') {
      final prescriptionId = (data['prescriptionId'] ?? '').toString();
      if (prescriptionId.isNotEmpty) {
        await _openPrescriptionDetail(context, prescriptionId);
        return;
      }
      if (!context.mounted) return;
      Navigator.pushNamed(context, '/prescriptions');
      return;
    }

    // ── Postponed offer ───────────────────────────────────────────
    if (type == 'postpone_offer' && role == UserRoles.patient) {
      final offerId = (data['offerId'] ?? '').toString();
      if (offerId.isNotEmpty) {
        if (!context.mounted) return;
        Navigator.pushNamed(
          context,
          '/postponed-offer',
          arguments: {'offerId': offerId},
        );
        return;
      }
    }

    if (!context.mounted) return;

    // ── PATIENT routing ───────────────────────────────────────────
    if (role == UserRoles.patient) {
      switch (type) {
        case 'chat_message':
          final senderId = (data['senderId'] ?? '').toString();
          final roomId = (data['roomId'] ?? '').toString();
          if (senderId.isNotEmpty) {
            Navigator.pushNamed(
              context,
              '/patient-chat',
              arguments: {'doctorId': senderId, 'roomId': roomId},
            );
          } else {
            Navigator.pushNamed(context, '/patient-chats');
          }
          break;
        case 'appointment_completed':
        case 'appointment_cancelled':
        case 'appointment_cancelled_admin':
        case 'appointment_rejected':
        case 'postpone_offer_expired':
        case 'postpone_offer_declined':
          Navigator.pushNamed(context, '/appointment-history');
          break;
        case 'review_approved':
          Navigator.pushNamed(context, '/appointment-history');
          break;
        default:
          // appointment_approved, appointment_request_sent, postpone_offer_accepted etc
          Navigator.pushNamed(context, '/upcoming-appointments');
      }
      return;
    }

    // ── DOCTOR routing ────────────────────────────────────────────
    if (role == UserRoles.doctor) {
      switch (type) {
        case 'chat_message':
          final senderId = (data['senderId'] ?? '').toString();
          if (kIsWeb) {
            // On web, go to doctor dashboard and switch to Chat tab
            Navigator.pushNamed(
              context,
              '/doctor-dashboard-web',
              arguments: {'initialTab': 2, 'patientId': senderId},
            );
          } else {
            if (senderId.isNotEmpty) {
              Navigator.pushNamed(
                context,
                '/doctor-chat',
                arguments: {'patientId': senderId},
              );
            } else {
              Navigator.pushNamed(context, '/doctor-chats');
            }
          }
          break;
        case 'doctor_approved':
          Navigator.pushNamed(
            context,
            kIsWeb ? '/doctor-dashboard-web' : '/doctor-dashboard',
          );
          break;
        case 'doctor_rejected':
          Navigator.pushNamed(
            context,
            kIsWeb ? '/doctor-dashboard-web' : '/doctor-dashboard',
          );
          break;
        case 'appointment_request':
        case 'appointment_requested':
        case 'admin_appointment_alert':
          // Go to dashboard — doctor sees pending requests there
          Navigator.pushNamed(
            context,
            kIsWeb ? '/doctor-dashboard-web' : '/doctor-dashboard',
          );
          break;
        default:
          Navigator.pushNamed(
            context,
            kIsWeb ? '/doctor-dashboard-web' : '/doctor-dashboard',
          );
      }
      return;
    }

    // ── ADMIN routing ─────────────────────────────────────────────
    if (role == UserRoles.admin) {
      int initialIndex = 0;
      if (type.contains('appointment')) initialIndex = 3;
      if (type.contains('doctor') ||
          type == 'doctor_approved' ||
          type == 'doctor_rejected')
        initialIndex = 2;
      if (type.contains('review')) initialIndex = 5;
      Navigator.pushNamed(
        context,
        '/admin-dashboard',
        arguments: {'initialIndex': initialIndex},
      );
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('User not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markAllAsRead(user.uid);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Marked all as read.')),
              );
            },
            child: const Text(
              'Mark all',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(FirestoreCollections.notifications)
            .where(NotificationFields.recipientId, isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notifications.'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs)
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              final aTs = aData[NotificationFields.createdAt];
              final bTs = bData[NotificationFields.createdAt];

              final aDate = aTs is Timestamp
                  ? aTs.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              final bDate = bTs is Timestamp
                  ? bTs.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);

              return bDate.compareTo(aDate);
            });
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet',
                style: AppTypography.bodyText,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = (data[NotificationFields.title] ?? '').toString();
              final body = (data[NotificationFields.body] ?? '').toString();
              final type = (data[NotificationFields.type] ?? '').toString();
              final isRead = (data[NotificationFields.isRead] ?? false) == true;
              final ts = data[NotificationFields.createdAt];
              final timeText = ts is Timestamp
                  ? _formatTime(ts.toDate())
                  : 'Now';
              final accent = _colorForType(type);

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                color: isRead ? Colors.white : const Color(0xFFEFF8F1),
                child: ListTile(
                  onTap: () async {
                    await doc.reference.update({
                      NotificationFields.isRead: true,
                    });
                    await _handleNotificationTap(context, data);
                  },
                  leading: CircleAvatar(
                    backgroundColor: accent.withOpacity(0.14),
                    child: Icon(_iconForType(type), color: accent),
                  ),
                  title: Text(
                    title,
                    style: AppTypography.bodyText.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(body, style: AppTypography.bodyText),
                      const SizedBox(height: 4),
                      Text(
                        timeText,
                        style: AppTypography.bodyText.copyWith(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
