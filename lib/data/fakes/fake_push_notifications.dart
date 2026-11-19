import '../../domain/ports/push_notifications.dart';

/// Records notifications instead of showing them, for tests and keyless runs.
class FakePushNotifications implements PushNotifications {
  final List<({int id, String title, String body, String? payload})> shown =
      <({int id, String title, String body, String? payload})>[];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupKey,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}
