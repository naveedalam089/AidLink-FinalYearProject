// Purpose: Doctor web section for messaging with patients.
// File: lib/views/doctor_web/sections/chat_section.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/services/chat_appointment_service.dart';
import '../../../core/services/chat_room_service.dart';
import '../../../core/services/message_service.dart';
import '../../../core/widgets/message_tick_icon.dart';
import '../../common/chat_info_screen.dart';

class ChatSection extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? appointmentId;

  /// Called when the doctor presses the close/back button in the chat header.
  final VoidCallback? onClose;

  const ChatSection({
    Key? key,
    required this.patientId,
    required this.patientName,
    this.appointmentId,
    this.onClose,
  }) : super(key: key);

  @override
  State<ChatSection> createState() => _ChatSectionState();
}

class _ChatSectionState extends State<ChatSection> {
  late final String _currentUserId;
  String _activePatientId = '';
  String _activePatientName = '';
  String? _activeAppointmentId;
  String? _roomId;
  String _patientPhotoUrl = '';
  int _limit = 50;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deliveredMarkedRoomIds = {};
  bool _sending = false;
  bool _loadingRoom = true;
  bool _noPatientSelected = false;
  bool _markingVisibleMessagesRead = false;
  bool _roomEnded = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _currentUserId = user?.uid ?? '';
    _activePatientId = widget.patientId;
    _activePatientName = widget.patientName;
    _activeAppointmentId = widget.appointmentId;
    _ensureAppointmentRooms();
    _initRoom();
  }

  @override
  void didUpdateWidget(covariant ChatSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If a new patient is selected, re-initialise the room.
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.appointmentId != widget.appointmentId) {
      setState(() {
        _activePatientId = widget.patientId;
        _activePatientName = widget.patientName;
        _activeAppointmentId = widget.appointmentId;
        _roomId = null;
        _patientPhotoUrl = '';
        _loadingRoom = true;
        _noPatientSelected = false;
      });
      _initRoom();
    }
  }

  Future<void> _initRoom() async {
    if (_activePatientId.isEmpty) {
      if (mounted)
        setState(() {
          _loadingRoom = false;
          _noPatientSelected = true;
        });
      return;
    }

    // Load patient photo in parallel
    _loadPatientPhoto();

    final appointmentId = (_activeAppointmentId ?? '').trim().isNotEmpty
        ? _activeAppointmentId!.trim()
        : await ChatAppointmentService.findApprovedAppointmentIdForPair(
            doctorId: _currentUserId,
            patientId: _activePatientId,
          );

    final roomId = MessageService.roomIdFor(_currentUserId, _activePatientId);
    await MessageService.getOrCreateRoom(
      userA: _currentUserId,
      userB: _activePatientId,
      appointmentId: appointmentId,
    );
    try {
      await MessageService.markRoomRead(roomId: roomId, userId: _currentUserId);
      await MessageService.markMessagesRead(
        roomId: roomId,
        readerId: _currentUserId,
      );
    } catch (_) {
      // Read receipts/unread counters are best-effort and must never block chat.
    }

    if (mounted) {
      final roomActive = await ChatRoomService.isRoomActive(roomId);
      setState(() {
        _roomId = roomId;
        _loadingRoom = false;
        _roomEnded = !roomActive;
      });
    }
  }

  Future<void> _loadPatientPhoto() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_activePatientId)
          .get();
      final url = (doc.data()?['profilePhotoUrl'] ?? '').toString();
      if (mounted) setState(() => _patientPhotoUrl = url);
    } catch (_) {}
  }

  Future<void> _ensureAppointmentRooms() async {
    if (_currentUserId.isEmpty) return;
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
            (status != 'approved' && status != 'accepted')) {
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

  Future<Map<String, dynamic>> _getPatientInfo(String patientId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .get();
      final data = doc.data() ?? <String, dynamic>{};
      final firstName = (data['firstName'] ?? '').toString();
      final lastName = (data['lastName'] ?? '').toString();
      final fullName = '$firstName $lastName'.trim();
      return {
        'name': fullName.isEmpty ? 'Patient' : fullName,
        'photoUrl': (data['profilePhotoUrl'] ?? '').toString(),
      };
    } catch (_) {
      return {'name': 'Patient', 'photoUrl': ''};
    }
  }

  void _openRoom({
    required String patientId,
    required String patientName,
    String? appointmentId,
  }) {
    setState(() {
      _activePatientId = patientId;
      _activePatientName = patientName;
      _activeAppointmentId = appointmentId;
      _roomId = null;
      _patientPhotoUrl = '';
      _loadingRoom = true;
      _noPatientSelected = false;
    });
    _initRoom();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _roomId == null || _roomEnded) return;
    setState(() => _sending = true);
    try {
      await MessageService.sendMessage(
        roomId: _roomId!,
        senderId: _currentUserId,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section heading row with optional back button
        Row(
          children: [
            if (_activePatientId.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.primaryGreen,
                ),
                tooltip: 'Back',
                onPressed: widget.onClose != null
                    ? () => widget.onClose!()
                    : null,
              ),
            Text(
              _activePatientId.isEmpty
                  ? 'Chats'
                  : 'Chat with $_activePatientName',
              style: AppTypography.heading2,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _activePatientId.isEmpty
              ? _chatInbox()
              : Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderGray),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _chatHeader(),
                      Expanded(child: _messageList()),
                      _composer(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: Colors.grey[300]),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No patient selected',
            style: AppTypography.heading3.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Open a chat from the Appointments section.',
            style: AppTypography.bodyText.copyWith(color: Colors.grey[400]),
          ),
        ],
      ),
    );
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

  Widget _chatInbox() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderGray),
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rooms')
            .where('participants', arrayContains: _currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load chats'));
          }
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

          if (rooms.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet',
                style: AppTypography.bodyText.copyWith(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final roomDoc = rooms[index];
              final roomData = roomDoc.data() as Map<String, dynamic>;
              final participants = List<String>.from(
                roomData['participants'] ?? [],
              );
              final patientId = participants.firstWhere(
                (id) => id != _currentUserId,
                orElse: () => '',
              );
              if (patientId.isEmpty) return const SizedBox.shrink();

              if (_deliveredMarkedRoomIds.add(roomDoc.id)) {
                MessageService.markMessagesDelivered(
                  roomId: roomDoc.id,
                  recipientId: _currentUserId,
                ).catchError((_) {});
              }

              final unreadCounts = Map<String, dynamic>.from(
                roomData['unreadCounts'] ?? {},
              );
              final unreadCount = unreadCounts[_currentUserId] ?? 0;
              final hasUnread = unreadCount > 0;
              final lastMessage = (roomData['lastMessage'] ?? '').toString();
              final lastSenderId = (roomData['lastSenderId'] ?? '').toString();
              final lastDelivered =
                  (roomData['lastDelivered'] as bool?) ?? false;
              final lastReadBy = List<String>.from(
                roomData['lastReadBy'] ?? [],
              );
              final lastAt = roomData['lastAt'] as Timestamp?;
              final appointmentId = (roomData['appointmentId'] ?? '')
                  .toString();

              return FutureBuilder<Map<String, dynamic>>(
                future: _getPatientInfo(patientId),
                builder: (context, patientSnap) {
                  final patientInfo =
                      patientSnap.data ?? {'name': 'Patient', 'photoUrl': ''};
                  final patientName = patientInfo['name'] ?? 'Patient';
                  final photoUrl = patientInfo['photoUrl'] ?? '';

                  return ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryGreen,
                          backgroundImage: photoUrl.isNotEmpty
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 20,
                              height: 20,
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
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading3.copyWith(
                        fontWeight: hasUnread
                            ? FontWeight.bold
                            : FontWeight.w600,
                      ),
                    ),
                    subtitle: Row(
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
                            lastMessage.isEmpty
                                ? 'No messages yet'
                                : lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? Colors.black54
                                  : Colors.grey[600],
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      _formatTimestamp(lastAt),
                      style: TextStyle(
                        color: hasUnread
                            ? AppColors.primaryGreen
                            : Colors.grey[500],
                        fontSize: 12,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => _openRoom(
                      patientId: patientId,
                      patientName: patientName,
                      appointmentId: appointmentId.isEmpty
                          ? null
                          : appointmentId,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp? ts) {
    if (ts == null) return '';
    final date = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    if (messageDate == today) {
      return TimeOfDay.fromDateTime(date).format(context);
    }
    if (messageDate == yesterday) {
      return 'Yesterday';
    }
    return '${messageDate.day}/${messageDate.month}';
  }

  Widget _chatHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryGreen,
            backgroundImage: _patientPhotoUrl.isNotEmpty
                ? NetworkImage(_patientPhotoUrl)
                : null,
            child: _patientPhotoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 20)
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activePatientName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Patient',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          if (_activePatientId.isNotEmpty) ...[
            if (_roomId != null)
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryGreen,
                ),
                tooltip: 'Chat info',
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withOpacity(0.3),
                    builder: (_) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      insetPadding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 0,
                      ),
                      child: SizedBox(
                        width: 420,
                        height: 360,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Scaffold(
                            backgroundColor: Colors.white,
                            appBar: AppBar(
                              backgroundColor: AppColors.primaryGreen,
                              elevation: 0,
                              leading: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                              title: const Text(
                                'Chat Info',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              automaticallyImplyLeading: false,
                            ),
                            body: SingleChildScrollView(
                              child: Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    color: AppColors.primaryGreen.withOpacity(
                                      0.06,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 28,
                                      horizontal: 24,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 36,
                                          backgroundColor:
                                              AppColors.primaryGreen,
                                          backgroundImage:
                                              _patientPhotoUrl.isNotEmpty
                                              ? NetworkImage(_patientPhotoUrl)
                                              : null,
                                          child: _patientPhotoUrl.isEmpty
                                              ? const Icon(
                                                  Icons.person,
                                                  size: 36,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              widget.patientName,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryGreen
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Patient',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.primaryGreen,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  StreamBuilder<DocumentSnapshot>(
                                    stream: _roomId != null
                                        ? FirebaseFirestore.instance
                                              .collection('rooms')
                                              .doc(_roomId)
                                              .snapshots()
                                        : null,
                                    builder: (ctx, snap) {
                                      final data =
                                          (snap.hasData && snap.data!.exists)
                                          ? (snap.data!.data()
                                                    as Map<String, dynamic>? ??
                                                {})
                                          : <String, dynamic>{};
                                      final isEnded =
                                          (data['status'] ?? '').toString() ==
                                          'ended';
                                      return _infoDialogTile(
                                        icon: isEnded
                                            ? Icons.block
                                            : Icons.check_circle_outline,
                                        iconColor: isEnded
                                            ? Colors.red
                                            : AppColors.primaryGreen,
                                        label: 'Conversation Status',
                                        value: isEnded
                                            ? 'Chat ended'
                                            : 'Active',
                                        valueColor: isEnded
                                            ? Colors.red
                                            : AppColors.primaryGreen,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: const Text('End Chat'),
                                              content: const Text(
                                                'This will prevent the patient from sending new messages. Are you sure?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                    'End Chat',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true &&
                                              _roomId != null) {
                                            await ChatRoomService.endRoom(
                                              roomId: _roomId!,
                                              endedBy: _currentUserId,
                                            );
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red.shade600,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.block,
                                          color: Colors.white,
                                        ),
                                        label: const Text(
                                          'End Chat',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.primaryGreen),
              tooltip: 'Close chat',
              onPressed: widget.onClose != null
                  ? () => widget.onClose!()
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoDialogTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList() {
    if (_loadingRoom) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_roomId == null) {
      return const Center(child: Text('Could not open chat room.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: MessageService.streamMessages(_roomId!, limit: _limit),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load messages'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final showLoadEarlier = docs.length == _limit;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _markVisibleMessagesRead();
        });

        return Container(
          color: const Color(0xFFF5F5F5),
          child: Column(
            children: [
              if (showLoadEarlier)
                TextButton(
                  onPressed: () => setState(() => _limit += 50),
                  child: const Text('Load earlier messages'),
                ),
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final d = docs[index].data() as Map<String, dynamic>;
                          final sender = (d['senderId'] ?? '').toString();
                          final text = (d['text'] ?? '').toString();
                          final ts = d['createdAt'] as Timestamp?;
                          final isMe = sender == _currentUserId;

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
                                    vertical: 3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.sm,
                                    horizontal: AppSpacing.md,
                                  ),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.primaryGreen
                                        : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(
                                        isMe ? 16 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 16,
                                      ),
                                    ),
                                    border: isMe
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 0.5,
                                          ),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 6,
                                    left: 4,
                                    right: 4,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTime(ts),
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
                                              (d['readBy'] as List?)?.contains(
                                                _activePatientId,
                                              ) ??
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
          ),
        );
      },
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Type your message…',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ElevatedButton(
            onPressed: _sending || _roomEnded ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
