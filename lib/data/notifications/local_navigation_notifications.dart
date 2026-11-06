import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/navigation_notifications.dart';

/// The ongoing ("permanent") notification shown while guidance runs.
///
/// Posted **natively** (a `openmaps/navigation` platform channel handled by
/// `MainActivity`) rather than through `flutter_local_notifications`, because
/// the Android 16 Live Update APIs it needs — `setShortCriticalText` (the
/// status-bar chip) and `setRequestPromotedOngoing` — are not exposed by the
/// plugin. The native side owns the channel, the progress bar and the
/// "Exit navigation" action, and reports the action tap back over the channel.
/// Every platform call is guarded, so a device without native support still
/// navigates.
class LocalNavigationNotifications implements NavigationNotifications {
  LocalNavigationNotifications({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const String channelName = 'openmaps/navigation';

  final MethodChannel _channel;
  final StreamController<void> _exitRequests =
      StreamController<void>.broadcast();

  @override
  Stream<void> get exitRequests => _exitRequests.stream;

  Future<void> _onMethodCall(MethodCall call) async {
    if (call.method == 'exitNavigation') {
      _exitRequests.add(null);
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
    int? progress,
    String? statusChip,
    TravelMode mode = TravelMode.drive,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', <String, Object?>{
        'title': title,
        'body': body,
        'progress': progress,
        'chip': statusChip,
        'mode': mode.name,
      });
    } catch (_) {
      // Native support unavailable; guidance continues without a notice.
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
