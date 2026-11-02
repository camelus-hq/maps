import '../../domain/ports/live_share_notifications.dart';

/// Records notification calls instead of showing anything (tests, keyless runs).
class FakeLiveShareNotifications implements LiveShareNotifications {
  /// What [requestPermission] returns.
  bool permissionGranted = true;

  int permissionRequests = 0;

  /// Whether a notification is currently shown.
  bool visible = false;

  String? title;

  String? body;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    visible = true;
    this.title = title;
    this.body = body;
  }

  @override
  Future<void> update({required String title, required String body}) async {
    visible = true;
    this.title = title;
    this.body = body;
  }

  @override
  Future<void> dismiss() async {
    visible = false;
    title = null;
    body = null;
  }
}
