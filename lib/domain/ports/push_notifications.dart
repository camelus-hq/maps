/// Shows a local notification for an incoming, decrypted push.
///
/// Behind an interface so the foreground dispatch can be tested, and so the app
/// layer never talks to the native plugin directly.
abstract interface class PushNotifications {
  /// Shows (or replaces) the notification with [id].
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupKey,
  });
}
