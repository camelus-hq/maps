import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../data/notifications/push_background_handler.dart';

/// Installs the FCM background message handler, once, at startup.
///
/// A no-op for web builds or builds without a push backend. The registration
/// itself is owned by `pushStatusProvider` (kept alive by
/// `PushNotificationLayer`).
void installPushBackgroundHandler(AppConfig config) {
  if (kIsWeb || !config.hasPushServer) {
    return;
  }
  FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);
}
