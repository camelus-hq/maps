import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../data/notifications/push_notification_content.dart';
import '../data/notifications/push_registrar.dart';
import '../domain/entities/push.dart';
import '../domain/ports/push_messaging.dart';
import '../domain/ports/push_notifications.dart';
import '../domain/ports/social_service.dart';
import 'config.dart';
import 'ports.dart';
import 'settings.dart';

/// Keeps the user's push registration in sync with their identity and token,
/// and turns **foreground** pushes into notifications.
///
/// Owned by [PushNotificationsController]: on start it initializes the transport
/// and registers, then re-registers whenever the identity changes (sign in/out)
/// or the transport rotates the token. While the app is foregrounded it decrypts
/// each incoming gift wrap and shows a notification for the kinds it surfaces
/// (a DM here; live shares are already drawn by the map's own subscription).
class PushRegistrationBootstrap {
  PushRegistrationBootstrap({
    required this.messaging,
    required this.registrar,
    required this.social,
    required this.notifications,
    this.transport = PushTransport.firebase,
    this.serverConfigured = false,
  });

  final PushMessaging messaging;
  final PushRegistrar registrar;
  final SocialService social;
  final PushNotifications notifications;

  /// The transport the user selected (Firebase by default).
  final PushTransport transport;

  /// Whether a push backend is configured in this build.
  final bool serverConfigured;

  /// The live status shown in settings.
  final ValueNotifier<PushStatus> status = ValueNotifier<PushStatus>(
    const PushStatus(),
  );

  StreamSubscription<String?>? _identitySub;
  StreamSubscription<PushToken>? _tokenSub;
  StreamSubscription<String>? _foregroundSub;
  bool _started = false;

  /// The token the last successful registration used, so a token event that
  /// races the first sync does not register twice.
  String? _registeredToken;

  /// The identity the last [sync] ran for, so the replayed first emission of
  /// [SocialService.identityChanges] does not register twice.
  String? _syncedIdentity;
  bool _hasSynced = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    _update(
      (PushStatus s) => s.copyWith(
        serverConfigured: serverConfigured,
        supported: messaging.isSupported,
        transport: transport,
        clearError: true,
      ),
    );
    await messaging.initialize();
    // Listen for token refreshes *before* the first sync: the stream does not
    // replay, so a token delivered while the sync is still waiting for one
    // would otherwise be dropped and leave the device unregistered.
    _tokenSub = messaging.tokenChanges.listen(_onToken);
    await sync();
    _identitySub = social.identityChanges.listen(_onIdentity);
    _foregroundSub = messaging.foregroundMessages.listen(_onForeground);
  }

  void _onIdentity(String? pubkey) {
    if (_hasSynced && pubkey == _syncedIdentity) {
      return;
    }
    unawaited(sync());
  }

  Future<void> _onToken(PushToken token) async {
    if (token.transport != transport || !social.isLoggedIn) {
      return;
    }
    if (token.value == _registeredToken) {
      return;
    }
    bool ok = false;
    String? error;
    try {
      ok = await registrar.register(token: token.value, transport: transport);
    } catch (e) {
      error = 'Could not reach the push server ($e).';
    }
    if (ok) {
      _registeredToken = token.value;
    }
    _update(
      (PushStatus s) => s.copyWith(
        hasToken: true,
        registered: ok,
        error: ok ? null : (error ?? 'The server rejected the registration.'),
        clearError: ok,
      ),
    );
  }

  /// Registers when signed in with push enabled; unregisters (and invalidates
  /// the device token) otherwise.
  Future<void> sync() async {
    _syncedIdentity = social.currentUserPubkey;
    _hasSynced = true;
    if (!serverConfigured) {
      _update(
        (PushStatus s) => s.copyWith(registered: false, clearError: true),
      );
      return;
    }
    if (!transport.isEnabled || !social.isLoggedIn) {
      // Signed out: the server cannot be told with a proof, so invalidate the
      // device token instead — the server drops a token it cannot deliver to.
      _registeredToken = null;
      await registrar.unregister();
      await messaging.deleteToken(transport);
      _update(
        (PushStatus s) => s.copyWith(
          hasToken: false,
          registered: false,
          error: transport.isEnabled
              ? 'Sign in to receive notifications.'
              : null,
          clearError: !transport.isEnabled,
        ),
      );
      return;
    }
    final bool granted = await messaging.requestPermission();
    _update((PushStatus s) => s.copyWith(permissionGranted: granted));
    final String? token = await messaging.tokenFor(transport);
    final bool hasToken = token != null && token.isNotEmpty;
    if (!hasToken) {
      // Show *why* there is no token (Firebase misconfigured, no Play services,
      // permission refused, still fetching) rather than a bare "not registered".
      final String reason = !granted
          ? 'Notifications are not allowed in system settings.'
          : messaging.lastError ?? 'Waiting for a device token…';
      _update(
        (PushStatus s) =>
            s.copyWith(hasToken: false, registered: false, error: reason),
      );
      return;
    }
    _update((PushStatus s) => s.copyWith(hasToken: true));
    bool ok = false;
    String? error;
    try {
      ok = await registrar.register(token: token, transport: transport);
    } catch (e) {
      error = 'Could not reach the push server ($e).';
    }
    if (ok) {
      _registeredToken = token;
    }
    _update(
      (PushStatus s) => s.copyWith(
        registered: ok,
        error: ok ? null : (error ?? 'The server rejected the registration.'),
        clearError: ok,
      ),
    );
  }

  /// A foreground push. Only DMs are surfaced — a live share is already drawn by
  /// the map's own relay subscription, so notifying again would duplicate it.
  Future<void> _onForeground(String encryptedEvent) async {
    final DecryptedPushEvent? event = await social.decryptPushEvent(
      encryptedEvent,
    );
    if (event == null ||
        event.kind != PushNotificationContent.directMessageKind) {
      return;
    }
    final PushNotificationContent? content =
        PushNotificationContent.fromDecryptedEvent(
          kind: event.kind,
          content: event.content,
          senderPubkey: event.senderPubkey,
        );
    if (content == null) {
      return;
    }
    await notifications.show(
      id: content.id,
      title: content.title,
      body: content.body,
      payload: content.payload,
    );
  }

  void _update(PushStatus Function(PushStatus) change) {
    status.value = change(status.value);
  }

  Future<void> dispose() async {
    await _identitySub?.cancel();
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
    _identitySub = null;
    _tokenSub = null;
    _foregroundSub = null;
  }
}

/// Owns the [PushRegistrationBootstrap] and exposes its [PushStatus].
///
/// Kept alive by the map home's `PushNotificationLayer`; rebuilding when the
/// transport preference changes re-syncs against the new transport.
class PushNotificationsController extends Notifier<PushStatus> {
  PushRegistrationBootstrap? _bootstrap;

  @override
  PushStatus build() {
    final AppConfig config = ref.watch(appConfigProvider);
    final PushTransport transport = ref.watch(
      settingsProvider.select((settings) => settings.pushTransport),
    );
    final SocialService social = ref.watch(socialServiceProvider);
    final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
      messaging: ref.watch(pushMessagingProvider),
      registrar: PushRegistrar(
        social: social,
        api: ref.watch(pushRegistrationApiProvider),
        relays: config.liveShareRelays,
      ),
      social: social,
      notifications: ref.watch(pushNotificationsProvider),
      transport: transport,
      serverConfigured: config.hasPushServer,
    );
    _bootstrap = bootstrap;

    void onStatus() => state = bootstrap.status.value;
    bootstrap.status.addListener(onStatus);
    ref.onDispose(() {
      bootstrap.status.removeListener(onStatus);
      unawaited(bootstrap.dispose());
    });

    unawaited(bootstrap.start().catchError((Object _) {}));
    return bootstrap.status.value;
  }

  /// Persists the transport choice (the provider rebuild re-syncs).
  Future<void> setTransport(PushTransport transport) =>
      ref.read(settingsProvider.notifier).setPushTransport(transport);

  /// Re-runs the registration sync (settings "retry").
  Future<void> refresh() => _bootstrap?.sync() ?? Future<void>.value();
}

final NotifierProvider<PushNotificationsController, PushStatus>
pushStatusProvider = NotifierProvider<PushNotificationsController, PushStatus>(
  PushNotificationsController.new,
);
