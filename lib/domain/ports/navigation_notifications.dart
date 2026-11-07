import '../entities/travel_mode.dart';

/// Shows the permanent ("ongoing") notification while turn-by-turn guidance is
/// running.
///
/// Implemented natively on Android so it can request promotion to an Android 16
/// **Live Update**: an Android **progress bar** (how much of the trip is
/// complete), an **"Exit navigation"** action, and a **status-bar chip** whose
/// short text carries the upcoming direction and whose icon matches the travel
/// mode. Platforms without that support degrade to the same ongoing notice
/// without progress, chip or actions. A no-op fake keeps tests and unsupported
/// platforms crash-free.
abstract interface class NavigationNotifications {
  /// Requests the OS notification permission (Android 13+). Returns whether it
  /// is granted now; `false` on platforms without a runtime prompt.
  Future<bool> requestPermission();

  /// Shows or replaces the ongoing navigation notification. [progress] is a
  /// 0–100 percentage (Android draws a progress bar); `null` hides the bar.
  /// [statusChip] is the short text for the Android 16 status-bar chip (the
  /// upcoming direction), or `null` to leave the chip to the system. [mode]
  /// selects the notification/status-chip glyph (car, bike, train, pedestrian).
  ///
  /// On Android the notice *is* a location **foreground service** notification:
  /// the first call starts the service and later calls update it, so the OS keeps
  /// delivering live position updates (and the status chip keeps updating) with
  /// the app backgrounded. [dismiss] stops that service.
  Future<void> show({
    required String title,
    required String body,
    int? progress,
    String? statusChip,
    TravelMode mode = TravelMode.drive,
  });

  /// Removes the ongoing notification (and, on Android, stops the foreground
  /// service it runs).
  Future<void> dismiss();

  /// Emits once whenever the user taps the notification's "Exit navigation"
  /// action, so guidance can stop from the shade without opening the app.
  Stream<void> get exitRequests;
}
