import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/constants/typography.dart';
import '../../core/services/chat_room_service.dart';
import '../../core/services/user_photo_service.dart';
import '../../core/widgets/user_avatar.dart';

class ChatInfoScreen extends StatefulWidget {
  final String roomId;
  final String participantName;
  final String participantPhotoUrl;
  final String currentUserId;
  final String? appointmentId;
  final bool isDoctor;

  const ChatInfoScreen({
    Key? key,
    required this.roomId,
    required this.participantName,
    required this.participantPhotoUrl,
    required this.currentUserId,
    this.appointmentId,
    required this.isDoctor,
  }) : super(key: key);

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  Map<String, dynamic> _otherUserData = {};

  @override
  void initState() {
    super.initState();
    _loadOtherUserData();
  }

  Future<void> _loadOtherUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      final participants = List<String>.from(
        userDoc.data()?['participants'] ?? [],
      );
      final otherUserId = participants.firstWhere(
        (id) => id != widget.currentUserId,
        orElse: () => '',
      );

      if (otherUserId.isEmpty) return;

      final otherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUserId)
          .get();
      Map<String, dynamic> data = Map<String, dynamic>.from(
        otherDoc.data() ?? {},
      );
      final existingPhoto = (data['profilePhotoUrl'] ?? '').toString();
      if (existingPhoto.isEmpty) {
        final url = await UserPhotoService.getPhotoUrl(otherUserId);
        data['profilePhotoUrl'] = url;
      }

      if (!mounted) return;
      setState(() => _otherUserData = data);
    } catch (_) {}
  }

  Future<void> _endChat(BuildContext context) async {
    await ChatRoomService.endRoom(
      roomId: widget.roomId,
      endedBy: widget.currentUserId,
    );
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat ended successfully.')));
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: valueColor ?? AppColors.primaryGreen),
      title: Text(label),
      subtitle: Text(
        value,
        style: TextStyle(color: valueColor ?? Colors.black87),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Chat info',
          style: AppTypography.heading3.copyWith(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  UserAvatar(
                    photoUrl: widget.participantPhotoUrl.isNotEmpty
                        ? widget.participantPhotoUrl
                        : (_otherUserData['profilePhotoUrl'] ?? '').toString(),
                    radius: 40,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.participantName,
                          style: AppTypography.heading3,
                        ),
                        Text(
                          widget.isDoctor ? 'Patient' : 'Doctor',
                          style: AppTypography.bodyText.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              StreamBuilder<DocumentSnapshot>(
                stream: widget.roomId.isNotEmpty
                    ? FirebaseFirestore.instance
                          .collection('rooms')
                          .doc(widget.roomId)
                          .snapshots()
                    : null,
                builder: (ctx, snap) {
                  final data = (snap.hasData && snap.data!.exists)
                      ? (snap.data!.data() as Map<String, dynamic>? ?? {})
                      : <String, dynamic>{};
                  final isEnded = (data['status'] ?? '').toString() == 'ended';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoTile(
                        icon: isEnded
                            ? Icons.block
                            : Icons.check_circle_outline,
                        label: 'Conversation status',
                        value: isEnded ? 'Chat ended' : 'Active',
                        valueColor: isEnded ? Colors.red : Colors.green,
                      ),
                      if (widget.isDoctor) ...[
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _endChat(context),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('End chat'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
