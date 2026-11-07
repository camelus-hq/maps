import 'package:flutter/services.dart';

import '../../domain/ports/live_share_notifications.dart';

/// The ongoing ("permanent") notification shown while a live share is active.
///
/// Posted **natively** (an `openmaps/live_share` platform channel handled by
/// `MainActivity`), like the navigation notice, rather than through
/// `flutter_local_notifications`: the notice *is* a location **foreground
/// service** notification, so the OS keeps the process alive and the share keeps
/// publishing with the app backgrounded — and no second, hidden notification is
/// needed. Every platform call is guarded, so sharing still works where native
/// support is unavailable — the notice is simply not drawn.
class LocalLiveShareNotifications implements LiveShareNotifications {
  LocalLiveShareNotifications({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const String channelName = 'openmaps/live_share';

  final MethodChannel _channel;

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
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
    try {
      await _channel.invokeMethod<void>('show', <String, Object?>{
        'title': title,
        'body': body,
      });
    } catch (_) {
      // Notifications unavailable; sharing continues.
    }
  }

  @override
  Future<void> dismiss() async {
    try {
      await _channel.invokeMethod<void>('dismiss');
    } catch (_) {
      // Nothing to dismiss.
    }
  }
}
