// Purpose: Display list of active conversations for doctor with room previews and unread badges
// File: lib/views/doctor_mobile/doctor_chats_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/message_service.dart';
import '../../core/services/user_photo_service.dart';
import '../../core/widgets/message_tick_icon.dart';
import '../../core/widgets/user_avatar.dart';

class DoctorChatsScreen extends StatefulWidget {
  const DoctorChatsScreen({Key? key}) : super(key: key);

  @override
  State<DoctorChatsScreen> createState() => _DoctorChatsScreenState();
}

class _DoctorChatsScreenState extends State<DoctorChatsScreen> {
  late final String _currentUserId;
  final Set<String> _deliveredMarkedRoomIds = {};

  @override
  void initState() {
    super.initState();
    // Initialize current user ID from Firebase Auth
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid ?? '';
    if (_currentUserId.isNotEmpty) {
      _ensureAppointmentRooms();
    }
  }

  String t(String english) => AppText.of(context, english);

  Future<void> _ensureAppointmentRooms() async {
    try {
      final appointments = await FirebaseFirestore.instance
          .collection('appointments')
          .where('doctorId', isEqualTo: _currentUserId)
          .get();

      for (final doc in appointments.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString();
        final patientId = (data['patientId'] ?? '').toString();
        if (patientId.isEmpty ||
            (status != 'approved' &&
                status != 'accepted' &&
                status != 'completed' &&
                status != 'no_show' &&
                status != 'cancelled' &&
                status != 'cancelled_late')) {
          continue;
        }
        await MessageService.getOrCreateRoom(
          userA: _currentUserId,
          userB: patientId,
          appointmentId: doc.id,
        );
      }
    } catch (_) {}
  }

  /// Format timestamp to readable string (Today, Yesterday, or date)
  /// Helps display message times in a human-friendly format
  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';

    final date = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return TimeOfDay.fromDateTime(date).format(context);
    } else if (messageDate == yesterday) {
      return t('Yesterday');
    } else {
      return '${messageDate.day}/${messageDate.month}';
    }
  }

  /// Fetch patient details from Firestore (name and photo)
  /// Used to display patient info in the chat list
  Future<Map<String, dynamic>> _getPatientInfo(String patientId) async {
    try {
      // Fetch user profile from Firestore
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();

      final data = userData.data() ?? {};
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();

      return {
        'name': fullName.isNotEmpty ? fullName : 'Patient',
        'photoUrl': await UserPhotoService.getPhotoUrl(patientId),
      };
    } catch (_) {
      return {'name': 'Patient', 'photoUrl': ''};
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prevent rendering if user not authenticated
    if (_currentUserId.isEmpty) {
      return Scaffold(body: Center(child: Text(t('User not logged in'))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          t('Messages'),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      // Stream rooms where current doctor is a participant
      // Ordered by most recent message first
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .where('participants', arrayContains: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          // Handle errors gracefully
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('DOCTOR ROOMS QUERY ERROR: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          // Show loading indicator while fetching
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!.docs.toList()
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

          // Show empty state when no conversations exist
          if (activeRooms.isEmpty) {
            return Container(
              color: const Color(0xFFF0F7F0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 80,
                      color: Color(0xFFA5D6A7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your patient conversations will appear here',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Display list of conversations
          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: activeRooms.length,
              itemBuilder: (context, index) {
                final roomDoc = activeRooms[index];
                final roomData = roomDoc.data() as Map<String, dynamic>;
                if (_deliveredMarkedRoomIds.add(roomDoc.id)) {
                  MessageService.markMessagesDelivered(
                    roomId: roomDoc.id,
                    recipientId: _currentUserId,
                  ).catchError((_) {});
                }
                final participants = List<String>.from(
                  roomData['participants'] ?? [],
                );

                final patientId = participants.firstWhere(
                  (id) => id != _currentUserId,
                  orElse: () => '',
                );

                if (patientId.isEmpty) return const SizedBox();

                final unreadCounts = Map<String, dynamic>.from(
                  roomData['unreadCounts'] ?? {},
                );
                final unreadCount = unreadCounts[_currentUserId] ?? 0;
                final hasUnread = unreadCount > 0;

                final lastMessage =
                    (roomData['lastMessage'] ??
                            roomData['lastMsg'] ??
                            roomData['last_message'] ??
                            '')
                        .toString();
                final lastSenderId = (roomData['lastSenderId'] ?? '')
                    .toString();
                final lastDelivered =
                    (roomData['lastDelivered'] as bool?) ?? false;
                final lastReadBy = List<String>.from(
                  roomData['lastReadBy'] ?? [],
                );
                final lastAt = roomData['lastAt'] as Timestamp?;

                return FutureBuilder<Map<String, dynamic>>(
                  future: _getPatientInfo(patientId),
                  builder: (context, patientSnap) {
                    if (!patientSnap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      );
                    }

                    final patientInfo = patientSnap.data!;
                    final patientName = patientInfo['name'] ?? 'Patient';
                    final photoUrl = patientInfo['photoUrl'] ?? '';

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: hasUnread
                            ? Border(
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
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/doctor-chat',
                            arguments: {
                              'patientId': patientId,
                              'patientName': patientName,
                            },
                          );
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                UserAvatar(photoUrl: photoUrl, radius: 26),
                                if (hasUnread)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 99
                                              ? '99+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          patientName,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: hasUnread
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        _formatTimestamp(lastAt),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: hasUnread
                                              ? AppColors.primaryGreen
                                              : Colors.grey[400],
                                          fontWeight: hasUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (lastSenderId == _currentUserId) ...[
                                        MessageTickIcon(
                                          delivered: lastDelivered,
                                          read: lastReadBy.contains(patientId),
                                          size: 13,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          lastMessage,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: hasUnread
                                                ? Colors.black54
                                                : Colors.grey[500],
                                            fontWeight: hasUnread
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
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
            ),
          );
        },
      ),
    );
  }
}
