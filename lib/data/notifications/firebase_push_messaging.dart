import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/push.dart';
import '../../domain/ports/push_messaging.dart';

/// [PushMessaging] over **Firebase Cloud Messaging**.
///
/// Only the messaging part of Firebase is used; no other Google library is
/// pulled in. Every platform call is guarded: if Firebase is not configured (no
/// `google-services.json` / `GoogleService-Info.plist`) the app still runs and
/// push is simply unavailable.
class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging({this.messaging});

  /// Injected for tests; defaults to [FirebaseMessaging.instance].
  FirebaseMessaging? messaging;
  bool _firebaseReady = false;
  String? _fcmToken;

  final StreamController<PushToken> _tokenChanges =
      StreamController<PushToken>.broadcast();
  final StreamController<String> _foreground =
      StreamController<String>.broadcast();

  StreamSubscription<String>? _fcmRegisteredSub;
  StreamSubscription<RemoteMessage>? _fcmMessageSub;

  FirebaseMessaging get _fcm => messaging ??= FirebaseMessaging.instance;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (!isSupported || _firebaseReady) {
      return;
    }
    _firebaseReady = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fcmRegisteredSub = _fcm.onRegistered.listen((String token) {
        _fcmToken = token;
        _tokenChanges.add(
          PushToken(transport: PushTransport.firebase, value: token),
        );
      });
      _fcmMessageSub = FirebaseMessaging.onMessage.listen(_onFcmMessage);
    } catch (error) {
      // Firebase is not configured for this build; push stays off.
      debugPrint('FCM unavailable: $error');
    }
  }

  void _onFcmMessage(RemoteMessage message) {
    final Object? encrypted = message.data['encryptedEvent'];
    if (encrypted is String && encrypted.isNotEmpty) {
      _foreground.add(encrypted);
    }
  }

  @override
  Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    try {
      final NotificationSettings settings = await _fcm.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> tokenFor(PushTransport transport) async {
    if (!isSupported || transport != PushTransport.firebase) {
      return null;
    }
    if (_fcmToken != null) {
      return _fcmToken;
    }
    try {
      await _fcm.register();
    } catch (_) {
      // Firebase not configured; fall through to the cached value.
    }
    if (_fcmToken != null) {
      return _fcmToken;
    }
    try {
      return await _fcm.onRegistered.first.timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<PushToken> get tokenChanges => _tokenChanges.stream;

  @override
  Stream<String> get foregroundMessages => _foreground.stream;

  @override
  Future<void> deleteToken(PushTransport transport) async {
    if (transport != PushTransport.firebase) {
      return;
    }
    _fcmToken = null;
    try {
      await _fcm.unregister();
    } catch (_) {
      // Not registered; nothing to invalidate.
    }
  }

  Future<void> dispose() async {
    await _fcmRegisteredSub?.cancel();
    await _fcmMessageSub?.cancel();
    await _tokenChanges.close();
    await _foreground.close();
  }
}
