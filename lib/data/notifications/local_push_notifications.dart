import 'package:openmaps_notifications/openmaps_notifications.dart';

import '../../domain/ports/push_notifications.dart';

/// [PushNotifications] backed by the first-party `openmaps_notifications`
/// plugin (the same one the background isolate uses).
class LocalPushNotifications implements PushNotifications {
  const LocalPushNotifications();

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupKey,
  }) => OpenMapsNotifications.show(
    id: id,
    title: title,
    body: body,
    payload: payload,
    groupKey: groupKey ?? 'openmaps_push',
  );
}
