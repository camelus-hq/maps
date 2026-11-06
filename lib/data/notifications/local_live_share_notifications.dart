import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/ports/live_share_notifications.dart';
import 'local_notification_host.dart';

/// The ongoing ("permanent") notification shown while a live share is active.
///
/// Backed by `flutter_local_notifications` through the shared
/// [LocalNotificationHost]. Every platform call is guarded: if the plugin is
/// unavailable (desktop tests, a device with notifications disabled) sharing
/// still works — the notice is simply not drawn.
class LocalLiveShareNotifications implements LiveShareNotifications {
  LocalLiveShareNotifications({LocalNotificationHost? host})
    : _host = host ?? LocalNotificationHost.shared;

  /// Stable id so updates replace the same notification instead of stacking.
  static const int notificationId = 7101;

  static const String channelId = 'openmaps.live_share';
  static const String channelName = 'Live location sharing';
  static const String channelDescription =
      'Shown while your live location is shared with friends.';

  final LocalNotificationHost _host;

  @override
  Future<bool> requestPermission() async {
    await _host.ensureInitialized();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final AndroidFlutterLocalNotificationsPlugin? android = _host.plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({required String title, required String body}) =>
      _show(title: title, body: body);

  @override
  Future<void> update({required String title, required String body}) =>
      _show(title: title, body: body);

  Future<void> _show({required String title, required String body}) async {
    await _host.ensureInitialized();
    try {
      await _host.plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            // An informational, non-dismissible notice while sharing.
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            category: AndroidNotificationCategory.locationSharing,
            visibility: NotificationVisibility.public,
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    } catch (_) {
      // Notifications unavailable; sharing continues.
    }
  }

  @override
  Future<void> dismiss() async {
    await _host.ensureInitialized();
    try {
      await _host.plugin.cancel(id: notificationId);
    } catch (_) {
      // Nothing to dismiss.
    }
  }
}
