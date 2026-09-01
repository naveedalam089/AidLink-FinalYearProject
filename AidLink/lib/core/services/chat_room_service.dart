import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<String> getRoomStatus(String roomId) async {
    try {
      final snapshot = await _firestore.collection('rooms').doc(roomId).get();
      return (snapshot.data()?['status'] ?? 'active').toString();
    } catch (_) {
      return 'active';
    }
  }

  static Future<bool> isRoomActive(String roomId) async {
    final status = await getRoomStatus(roomId);
    return status != 'ended';
  }

  static Future<void> endRoom({
    required String roomId,
    required String endedBy,
  }) async {
    await _firestore.collection('rooms').doc(roomId).set({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'endedBy': endedBy,
    }, SetOptions(merge: true));
  }
}
