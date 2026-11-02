/// Shows the permanent ("ongoing") notification while a live share is active.
///
/// Implemented with `flutter_local_notifications`; a no-op fake keeps tests and
/// unsupported platforms crash-free.
abstract interface class LiveShareNotifications {
  /// Requests the OS notification permission (Android 13+). Returns whether it
  /// is granted now; `false` on platforms without a runtime prompt.
  Future<bool> requestPermission();

  /// Shows the ongoing notification (or replaces the existing one).
  Future<void> show({required String title, required String body});

  /// Updates the ongoing notification's text without re-alerting the user.
  Future<void> update({required String title, required String body});

  /// Removes the ongoing notification.
  Future<void> dismiss();
}
