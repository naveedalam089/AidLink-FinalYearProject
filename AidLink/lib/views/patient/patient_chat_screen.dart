// Purpose: Patient one-on-one messaging with a doctor.
// File: lib/views/patient/patient_chat_screen.dart

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
import '../../core/widgets/message_tick_icon.dart';
import '../../core/widgets/user_avatar.dart';
import '../common/chat_info_screen.dart';

class PatientChatScreen extends StatefulWidget {
  final String doctorId;
  final String? doctorName;
  final String? appointmentId;

  const PatientChatScreen({
    Key? key,
    required this.doctorId,
    this.doctorName,
    this.appointmentId,
  }) : super(key: key);

  factory PatientChatScreen.fromArgs(Map<String, dynamic>? args) {
    return PatientChatScreen(
      doctorId: (args?['doctorId'] ?? '').toString(),
      doctorName: (args?['doctorName'] ?? 'Doctor').toString(),
      appointmentId: (args?['appointmentId'] ?? '').toString(),
    );
  }

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  String _currentUserId = '';
  late final String _doctorId;
  late final String _appointmentId;
  String? _roomId;
  String _doctorPhotoUrl = '';
  int _limit = 50;
  bool _appointmentValid = false;
  bool _checkingAppointment = true;
  bool _roomSetupError = false;
  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;
  bool _markingVisibleMessagesRead = false;
  bool _roomEnded = false;

  @override
  void initState() {
    super.initState();
    _doctorId = widget.doctorId;
    _appointmentId = widget.appointmentId ?? '';
    _checkAppointmentAndInitRoom();
    _loadDoctorPhoto();
  }

  Future<void> _loadDoctorPhoto() async {
    final url = await UserPhotoService.getPhotoUrl(widget.doctorId);
    if (mounted) setState(() => _doctorPhotoUrl = url);
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

  Future<void> _checkAppointmentAndInitRoom() async {
    if (_doctorId.isEmpty) {
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

      final resolvedAppointmentId = _appointmentId.isNotEmpty
          ? _appointmentId
          : await ChatAppointmentService.findApprovedAppointmentIdForPair(
              patientId: _currentUserId,
              doctorId: _doctorId,
            );

      bool canChat = false;
      if (resolvedAppointmentId != null && resolvedAppointmentId.isNotEmpty) {
        canChat = await ChatAppointmentService.canPatientChatFromAppointment(
          appointmentId: resolvedAppointmentId,
          patientId: _currentUserId,
          doctorId: _doctorId,
        );
      }

      if (!mounted) return;

      if (!canChat) {
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = false;
        });
        return;
      }

      _roomId = MessageService.roomIdFor(_currentUserId, _doctorId);

      try {
        await MessageService.getOrCreateRoom(
          userA: _currentUserId,
          userB: _doctorId,
          appointmentId: resolvedAppointmentId,
        );
      } catch (e) {
        final msg = e.toString();
        final isPermDenied = msg.contains('permission-denied');
        if (isPermDenied) {
          if (mounted) {
            setState(() {
              _checkingAppointment = false;
              _appointmentValid = true;
              _roomSetupError = false;
              _roomId = MessageService.roomIdFor(_currentUserId, _doctorId);
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            _checkingAppointment = false;
            _appointmentValid = false;
          });
        }
        return;
      }

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
        // Read receipts/unread counters are best-effort and must never block chat.
      }

      final roomActive = await ChatRoomService.isRoomActive(_roomId!);

      if (mounted) {
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = true;
          _roomSetupError = false;
          _roomEnded = !roomActive;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingAppointment = false;
          _appointmentValid = false;
        });
      }
    }
  }

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty ||
        _sending ||
        _roomId == null ||
        !_appointmentValid ||
        _roomSetupError ||
        _roomEnded)
      return;
    setState(() => _sending = true);
    try {
      await MessageService.sendMessage(
        roomId: _roomId!,
        senderId: _currentUserId,
        text: text,
      );
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String t(String english) => AppText.of(context, english);
    final String doctorName = widget.doctorName ?? 'Doctor';

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
                    participantName: doctorName,
                    participantPhotoUrl: _doctorPhotoUrl,
                    currentUserId: _currentUserId,
                    appointmentId: _appointmentId,
                    isDoctor: false,
                  ),
                ),
              ),
            ),
        ],
        title: Row(
          children: [
            UserAvatar(
              photoUrl: _doctorPhotoUrl,
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
                  doctorName,
                  style: AppTypography.heading3.copyWith(color: Colors.white),
                ),
                Text(
                  'Doctor',
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
                        'You need an approved appointment with this doctor to chat',
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
                      if (_roomSetupError) {
                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              color: Colors.red.withOpacity(0.08),
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Chat creation blocked by Firestore rules. You may be able to view messages but sending is disabled. Check Firestore rules for `rooms` write permissions.',
                                      style: AppTypography.bodyText.copyWith(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                        );
                      }
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
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _formatMessageTime(ts),
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[500],
                                              ),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              MessageTickIcon(
                                                delivered:
                                                    (d['delivered'] as bool?) ??
                                                    false,
                                                read:
                                                    (d['readBy'] as List?)
                                                        ?.contains(_doctorId) ??
                                                    false,
                                              ),
                                            ],
                                          ],
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
