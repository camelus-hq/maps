import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// OpenMaps' own local-notification channel.
///
/// This is a Flutter **plugin** rather than a `MethodChannel` registered in
/// `MainActivity` for one reason: a data-only FCM push wakes a Dart callback in
/// a *separate* Flutter engine, and only pubspec plugins are registered on that
/// engine. Since the wake-up isolate is the only place a gift wrap can be
/// decrypted, it is also the only place that knows what the notification should
/// say — so it needs a channel that exists there too.
///
/// Every call is guarded: an unavailable platform or a native failure must
/// never take down a background isolate.
class OpenMapsNotifications {
  OpenMapsNotifications._();

  static const MethodChannel channel = MethodChannel(
    'openmaps/push_notifications',
  );

  /// Whether this platform has a native implementation.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Shows a notification, replacing any existing one with the same [id].
  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? groupKey,
  }) async {
    if (!isSupported) {
      return;
    }
    await _invoke('show', <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'payload': ?payload,
      'groupKey': ?groupKey,
    });
  }

  /// Removes the notification with [id] (shown or pending).
  static Future<void> cancel(int id) async {
    if (!isSupported) {
      return;
    }
    await _invoke('cancel', <String, Object?>{'id': id});
  }

  /// Asks for notification permission. Returns whether it is granted now.
  static Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _invoke(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // Native refused (e.g. permission); nothing to do.
    } on MissingPluginException {
      // No native implementation on this platform.
    }
  }
}
