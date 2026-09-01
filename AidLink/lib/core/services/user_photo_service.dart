import 'package:cloud_firestore/cloud_firestore.dart';

class UserPhotoService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<String> getPhotoUrl(String uid) async {
    if (uid.isEmpty) return '';
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final url = (userDoc.data()?['profilePhotoUrl'] ?? '').toString();
        if (url.isNotEmpty) return url;
      }

      final doctorDoc = await _firestore.collection('doctors').doc(uid).get();
      if (doctorDoc.exists) {
        final url =
            (doctorDoc.data()?['profilePhotoUrl'] ??
                    doctorDoc.data()?['photoUrl'] ??
                    '')
                .toString();
        if (url.isNotEmpty) return url;
      }

      return '';
    } catch (_) {
      return '';
    }
  }
}
