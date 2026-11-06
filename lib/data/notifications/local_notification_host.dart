import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// One process-wide owner of the `flutter_local_notifications` plugin.
///
/// `FlutterLocalNotificationsPlugin()` is a singleton and its `initialize` call
/// registers a **single** notification-response callback, so two independent
/// adapters (live-share and navigation) must not each call `initialize` — the
/// last one would win and steal the other's notification actions. This host
/// initializes the plugin exactly once and fans every response out to whoever
/// listens.
class LocalNotificationHost {
  LocalNotificationHost({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static LocalNotificationHost? _shared;

  /// The process-wide host used by the real adapters.
  static LocalNotificationHost get shared =>
      _shared ??= LocalNotificationHost();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<NotificationResponse> _responses =
      StreamController<NotificationResponse>.broadcast();

  bool _initialized = false;

  FlutterLocalNotificationsPlugin get plugin => _plugin;

  /// Every notification response (an action tap, or a tap on the notice).
  Stream<NotificationResponse> get responses => _responses.stream;

  /// Initializes the plugin once (Android first): registers the response
  /// dispatch and the launch icon. Every platform call is guarded — if the
  /// plugin is unavailable (desktop tests, notifications disabled) the app keeps
  /// running without notices.
  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _responses.add,
      );
    } catch (_) {
      // Unsupported platform / missing channel: degrade silently.
    }
  }
}
