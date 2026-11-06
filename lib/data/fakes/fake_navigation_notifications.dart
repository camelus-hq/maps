import 'dart:async';

import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/navigation_notifications.dart';

/// Records navigation-notification calls instead of showing anything (tests,
/// keyless runs, unsupported platforms). [tapExit] simulates the shade's
/// "Exit navigation" action.
class FakeNavigationNotifications implements NavigationNotifications {
  /// What [requestPermission] returns.
  bool permissionGranted = true;

  int permissionRequests = 0;

  /// Whether a notification is currently shown.
  bool visible = false;

  String? title;

  String? body;

  /// The last 0–100 progress reported, or `null` when the bar is hidden.
  int? progress;

  /// The last status-chip text (upcoming direction), or `null`.
  String? statusChip;

  /// The last travel mode reported (selects the icon).
  TravelMode? mode;

  final StreamController<void> _exitRequests =
      StreamController<void>.broadcast();

  @override
  Stream<void> get exitRequests => _exitRequests.stream;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    int? progress,
    String? statusChip,
    TravelMode mode = TravelMode.drive,
  }) async {
    visible = true;
    this.title = title;
    this.body = body;
    this.progress = progress;
    this.statusChip = statusChip;
    this.mode = mode;
  }

  @override
  Future<void> dismiss() async {
    visible = false;
    title = null;
    body = null;
    progress = null;
    statusChip = null;
    mode = null;
  }

  /// Simulates the user tapping "Exit navigation" on the notification.
  void tapExit() => _exitRequests.add(null);

  Future<void> dispose() => _exitRequests.close();
}
