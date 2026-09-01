import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_values.dart';
import 'notification_service.dart';

class MessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generate deterministic roomId for a 1:1 chat (sorted ids)
  static String roomIdFor(String a, String b) {
    final parts = [a, b]..sort();
    return '${parts[0]}_${parts[1]}';
  }

  // Create or ensure a room document exists for two participants
  static Future<String> getOrCreateRoom({
    required String userA,
    required String userB,
    String? appointmentId,
  }) async {
    final roomId = roomIdFor(userA, userB);
    final ref = _firestore.collection('rooms').doc(roomId);
    final data = {
      'participants': [userA, userB],
      'lastMessage': null,
      'lastAt': null,
      'unreadCounts': {userA: 0, userB: 0},
    };
    if (appointmentId != null && appointmentId.isNotEmpty) {
      data['appointmentId'] = appointmentId;
    }
    await ref.set(data, SetOptions(merge: true));
    return roomId;
  }

  // Stream messages in a room (realtime)
  static Stream<QuerySnapshot> streamMessages(String roomId, {int limit = 50}) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Send a message to a room (adds message + updates room preview)
  static Future<void> sendMessage({
    required String roomId,
    required String senderId,
    required String text,
    String? attachmentUrl,
  }) async {
    final messagesRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages');

    final messageData = {
      'senderId': senderId,
      'text': text,
      'attachmentUrl': attachmentUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
      'delivered': false,
      'type': 'text',
    };

    final write = messagesRef.doc();
    await write.set(messageData);
    // Update room preview atomically and increment unread counts for other participants
    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnap = await roomRef.get();
    final roomData = roomSnap.data() ?? <String, dynamic>{};
    final participants = (roomData['participants'] is List)
        ? List<String>.from(roomData['participants'])
        : <String>[];

    // Build unreadCounts increment map for participants != sender
    final Map<String, dynamic> unreadIncrements = {};
    for (final p in participants) {
      if (p != senderId) {
        unreadIncrements['unreadCounts.$p'] = FieldValue.increment(1);
      }
    }

    final updateData = {
      'lastMessage': text,
      'lastSenderId': senderId,
      'lastDelivered': false,
      'lastReadBy': <String>[],
      'lastAt': FieldValue.serverTimestamp(),
      ...unreadIncrements,
    };

    await roomRef.set(updateData, SetOptions(merge: true));

    // Create in-app notification documents for other participants (client-side notification creation works on Spark)
    for (final p in participants) {
      if (p == senderId) continue;
      try {
        // Try to read recipient role from user doc (best-effort)
        final userSnap = await _firestore
            .collection(FirestoreCollections.users)
            .doc(p)
            .get();
        final udata = userSnap.data() ?? <String, dynamic>{};
        final recipientRole = (udata['role'] ?? UserRoles.patient).toString();

        await NotificationService.createNotification(
          recipientId: p,
          recipientRole: recipientRole,
          title: 'New message',
          body: text.length > 120 ? '${text.substring(0, 120)}...' : text,
          type: 'chat_message',
          data: {'roomId': roomId, 'senderId': senderId, 'messageId': write.id},
        );
      } catch (_) {
        // Swallow notification errors to avoid blocking message send
      }
    }
  }

  // Mark room-level unread count as read for a user.
  static Future<void> markRoomRead({
    required String roomId,
    required String userId,
  }) async {
    final roomRef = _firestore.collection('rooms').doc(roomId);
    await roomRef.set({
      'unreadCounts.$userId': 0,
    }, SetOptions(merge: true));
  }

  /// Mark all undelivered messages in a room as delivered for the given recipient.
  /// Call this when the OTHER participant's device receives/streams the room.
  static Future<void> markMessagesDelivered({
    required String roomId,
    required String recipientId,
  }) async {
    final messagesRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages');
    final roomMessages = await messagesRef.get();
    final undelivered = roomMessages.docs.where((doc) {
      final data = doc.data();
      return (data['senderId'] ?? '').toString() != recipientId &&
          (data['delivered'] as bool?) != true;
    }).toList();
    if (undelivered.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in undelivered) {
      batch.update(doc.reference, {'delivered': true});
    }
    await batch.commit();

    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnap = await roomRef.get();
    final roomData = roomSnap.data() ?? <String, dynamic>{};
    if ((roomData['lastSenderId'] ?? '').toString() != recipientId) {
      await roomRef.set({'lastDelivered': true}, SetOptions(merge: true));
    }
  }

  /// Mark all messages in a room as read by the given user.
  /// Call this when the user has the chat screen open and visible.
  static Future<void> markMessagesRead({
    required String roomId,
    required String readerId,
  }) async {
    final messagesRef = _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('messages');
    final roomMessages = await messagesRef.get();
    final batch = _firestore.batch();
    bool hasWrites = false;
    for (final doc in roomMessages.docs) {
      final data = doc.data();
      if ((data['senderId'] ?? '').toString() == readerId) continue;
      final readBy = List<String>.from(data['readBy'] ?? []);
      if (!readBy.contains(readerId)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([readerId]),
          'delivered': true,
        });
        hasWrites = true;
      }
    }
    if (hasWrites) await batch.commit();

    final roomRef = _firestore.collection('rooms').doc(roomId);
    final roomSnap = await roomRef.get();
    final roomData = roomSnap.data() ?? <String, dynamic>{};
    if ((roomData['lastSenderId'] ?? '').toString() != readerId) {
      await roomRef.set({
        'lastDelivered': true,
        'lastReadBy': FieldValue.arrayUnion([readerId]),
      }, SetOptions(merge: true));
    }
  }
}
