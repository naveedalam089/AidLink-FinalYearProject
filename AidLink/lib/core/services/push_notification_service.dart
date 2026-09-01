/// Push/FCM is intentionally disabled on the Spark plan.
///
/// AidLink uses Firestore notification documents and realtime listeners for
/// in-app notification badges and deep links instead of FCM push delivery.
class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  static Future<void> requestRuntimePermissions() async {}
}
