// Purpose: Doctor one-on-one messaging with a patient.
// File: lib/views/doctor_mobile/doctor_chat_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/message_service.dart';
import '../../core/services/chat_appointment_service.dart';
import '../../core/services/chat_room_service.dart';
import '../../core/services/user_photo_service.dart';
import '../../core/widgets/user_avatar.dart';
import '../common/chat_info_screen.dart';

class DoctorChatScreen extends StatefulWidget {
  final String patientId;
  final String? patientName;

  const DoctorChatScreen({Key? key, required this.patientId, this.patientName})
    : super(key: key);

  factory DoctorChatScreen.fromArgs(Map<String, dynamic>? args) {
    return DoctorChatScreen(
      patientId: (args?['patientId'] ?? '').toString(),
      patientName: (args?['patientName'] ?? 'Patient').toString(),
    );
  }

  @override
  State<DoctorChatScreen> createState() => _DoctorChatScreenState();
}

class _DoctorChatScreenState extends State<DoctorChatScreen> {
  String _currentUserId = '';
  late final String _patientId;
  String? _roomId;
  String _patientPhotoUrl = '';
  int _limit = 50;
  bool _appointmentValid = false;
  bool _checkingAppointment = true;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  bool _markingVisibleMessagesRead = false;
  bool _roomEnded = false;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    _checkAppointmentAndInitRoom();
    _loadPatientPhoto();
  }

  Future<void> _loadPatientPhoto() async {
    final url = await UserPhotoService.getPhotoUrl(widget.patientId);
    if (mounted) setState(() => _patientPhotoUrl = url);
  }

  Future<String?> _resolveCurrentUserId() async {
    final existingUser = FirebaseAuth.instance.currentUser;
    if (existingUser != null) {
      return existingUser.uid;
    }

    try {
      final user = await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((value) => value != null)
          .timeout(const Duration(seconds: 5));
      return user?.uid;
    } catch (_) {
      return FirebaseAuth.instance.currentUser?.uid;
    }
  }

  /// Check if doctor has accepted appointment with patient
  /// Only allow chat access after appointment is accepted
  Future<void> _checkAppointmentAndInitRoom() async {
    if (_patientId.isEmpty) {
      if (mounted) setState(() => _checkingAppointment = false);
      return;
    }

    try {
      _currentUserId = (await _resolveCurrentUserId()) ?? '';
      if (_currentUserId.isEmpty) {
        if (mounted) {
          setState(() {
            _checkingAppointment = false;
            _appointmentValid = false;
          });
        }
        return;
      }

      final appointmentId =
          await ChatAppointmentService.findApprovedAppointmentIdForPair(
            doctorId: _currentUserId,
            patientId: _patientId,
          );

      // Verify appointment exists and is accepted
      bool canChat = false;
      if (appointmentId != null && appointmentId.isNotEmpty) {
        canChat = await ChatAppointmentService.canPatientChatFromAppointment(
          doctorId: _currentUserId,
          patientId: _patientId,
          appointmentId: appointmentId,
        );
      }

      if (!mounted) return;

      if (!canChat) {
        // Appointment not found or not accepted - prevent chat
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = false;
        });
        return;
      }

      // Appointment valid - initialize room
      _roomId = MessageService.roomIdFor(_currentUserId, _patientId);
      await MessageService.getOrCreateRoom(
        userA: _currentUserId,
        userB: _patientId,
        appointmentId: appointmentId,
      );
      try {
        // Mark room as read when entering chat.
        await MessageService.markRoomRead(
          roomId: _roomId!,
          userId: _currentUserId,
        );
        await MessageService.markMessagesRead(
          roomId: _roomId!,
          readerId: _currentUserId,
        );
      } catch (_) {
        // Read receipts/unread counters are best-effort and must never block chat.
      }

      final roomActive = await ChatRoomService.isRoomActive(_roomId!);

      if (mounted) {
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = true;
          _roomEnded = !roomActive;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = false;
        });
      }
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    // Ensure appointment is valid and room exists
    if (text.isEmpty ||
        _sending ||
        _roomId == null ||
        !_appointmentValid ||
        _roomEnded)
      return;
    setState(() => _sending = true);
    try {
      // Send message through MessageService
      await MessageService.sendMessage(
        roomId: _roomId!,
        senderId: _currentUserId,
        text: text,
      );
      // Clear input after successful send
      _messageController.clear();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _markVisibleMessagesRead() async {
    if (_roomId == null ||
        _currentUserId.isEmpty ||
        _markingVisibleMessagesRead) {
      return;
    }
    _markingVisibleMessagesRead = true;
    try {
      await MessageService.markRoomRead(
        roomId: _roomId!,
        userId: _currentUserId,
      );
      await MessageService.markMessagesRead(
        roomId: _roomId!,
        readerId: _currentUserId,
      );
    } catch (_) {
    } finally {
      _markingVisibleMessagesRead = false;
    }
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- Build one-on-one chat screen with patient ---
    String t(String english) => AppText.of(context, english);
    final String patientName = widget.patientName ?? 'Patient';

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_roomId != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatInfoScreen(
                    roomId: _roomId!,
                    participantName: patientName,
                    participantPhotoUrl: _patientPhotoUrl,
                    currentUserId: _currentUserId,
                    isDoctor: true,
                  ),
                ),
              ),
            ),
        ],
        title: Row(
          children: [
            UserAvatar(
              photoUrl: _patientPhotoUrl,
              radius: 18,
              backgroundColor: Colors.white,
              fallbackChild: const Icon(
                Icons.person,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: AppTypography.heading3.copyWith(color: Colors.white),
                ),
                Text(
                  'Patient',
                  style: AppTypography.bodyText.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: _checkingAppointment
          ? const Center(child: CircularProgressIndicator())
          : !_appointmentValid
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 64,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      t('Cannot Access Chat'),
                      style: AppTypography.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      t(
                        'You need an accepted appointment with this patient to chat',
                      ),
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(t('Go Back')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _roomId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: MessageService.streamMessages(
                      _roomId!,
                      limit: _limit,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return const Center(
                          child: Text('Could not load messages'),
                        );
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());

                      final docs = snapshot.data!.docs;
                      final showLoadEarlier = docs.length == _limit;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markVisibleMessagesRead();
                      });

                      return Column(
                        children: [
                          if (showLoadEarlier)
                            TextButton(
                              onPressed: () => setState(() => _limit += 50),
                              child: const Text('Load earlier messages'),
                            ),
                          Expanded(
                            child: ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final d =
                                    docs[index].data() as Map<String, dynamic>;
                                final sender = (d['senderId'] ?? '').toString();
                                final text = (d['text'] ?? '').toString();
                                final isMe = sender == _currentUserId;
                                final ts = d['createdAt'] as Timestamp?;
                                return Align(
                                  alignment: isMe
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.sm,
                                          horizontal: AppSpacing.md,
                                        ),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.of(
                                                context,
                                              ).size.width *
                                              0.7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? AppColors.primaryGreen
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          text,
                                          style: AppTypography.bodyText
                                              .copyWith(
                                                color: isMe
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          left: 6,
                                          right: 6,
                                        ),
                                        child: Text(
                                          _formatMessageTime(ts),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.borderGray),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                          color: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
