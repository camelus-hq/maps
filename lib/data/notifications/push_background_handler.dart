import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';
import 'package:openmaps_notifications/openmaps_notifications.dart';

import '../../domain/entities/metric_event.dart';
import '../../domain/ports/app_database.dart';
import '../local/database/app_database_factory.dart';
import '../nostr/nostr_bootstrap.dart';
import 'push_notification_content.dart';

/// Entry point for a **data-only** push received while the app is backgrounded
/// or terminated.
///
/// `firebase_messaging` runs this in a separate Dart isolate. It is the only
/// place the gift wrap can be decrypted, so it is also the only place that knows
/// what the notification should say. The isolate **attaches** to the app's
/// ObjectBox store rather than opening a second one, and restores the Nostr
/// account from secure storage before unwrapping — so it can run while the main
/// app is alive with the same database open.
@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  final Object? encrypted = message.data['encryptedEvent'];
  if (encrypted is! String || encrypted.isEmpty) {
    return;
  }
  await handleBackgroundPush(encrypted);
}

/// Decrypts [encryptedEvent] and shows the matching notification.
///
/// Extracted from [pushBackgroundHandler] so it can be exercised without a
/// `RemoteMessage` / Firebase.
Future<void> handleBackgroundPush(String encryptedEvent) async {
  AppDatabase? database;
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (error) {
    developer.log('Firebase init failed', name: 'push.bg', error: error);
  }

  try {
    // Share the store with the running app (falls back to a normal open when
    // the app is not running). This is what lets the two isolates coexist.
    database = await openAppDatabaseAttached();

    final Ndk ndk = NostrBootstrap.createClient();
    final NdkFlutter ndkFlutter = NostrBootstrap.wrap(ndk);
    await ndkFlutter.restoreAccountsState();

    final Object? decoded = jsonDecode(encryptedEvent);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    final Nip01Event rumor = await ndk.giftWrap.fromGiftWrap(
      giftWrap: Nip01EventModel.fromJson(decoded),
    );

    await database.recordMetric(
      MetricEvent.create(
        'push.received',
        labels: <String, String>{'kind': '${rumor.kind}'},
      ),
    );

    final PushNotificationContent? content =
        PushNotificationContent.fromDecryptedEvent(
          kind: rumor.kind,
          content: rumor.content,
          senderPubkey: rumor.pubKey,
        );
    if (content == null) {
      return;
    }
    await OpenMapsNotifications.show(
      id: content.id,
      title: content.title,
      body: content.body,
      payload: content.payload,
      groupKey: 'openmaps_push',
    );
  } catch (error, stackTrace) {
    developer.log(
      'Background push failed',
      name: 'push.bg',
      error: error,
      stackTrace: stackTrace,
    );
  } finally {
    await database?.close();
  }
}
