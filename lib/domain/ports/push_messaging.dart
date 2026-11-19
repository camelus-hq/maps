import '../entities/push.dart';

/// Receives push messages from Firebase Cloud Messaging.
///
/// The payload is always an opaque NIP-59 gift wrap: the transport provider
/// cannot read it. Decryption happens in [PushNotificationContent] (in the
/// foreground) or in the background isolate, and only there is the message
/// meaning known.
///
/// Implemented in `lib/data/notifications/` and by a no-op fake so tests and
/// keyless runs never touch Firebase or a distributor.
abstract interface class PushMessaging {
  /// Whether this platform/build can receive push at all.
  bool get isSupported;

  /// A human-readable reason the transport could not provide a token (missing
  /// Firebase config, a failed registration, no Play services, …), or `null`
  /// when there is none. Shown in settings so a silent failure is visible.
  String? get lastError;

  /// Prepares the transport(s). Idempotent and safe to call at startup. A
  /// failed initialization may be retried by calling it again.
  Future<void> initialize();

  /// Requests OS notification permission. Returns whether it is granted.
  Future<bool> requestPermission();

  /// The current device token for [transport], or `null` when it is not
  /// available (Firebase not configured, permission not granted, or the token
  /// is still being fetched — watch [tokenChanges]).
  Future<String?> tokenFor(PushTransport transport);

  /// Emits a new token whenever the transport refreshes or first provides it.
  Stream<PushToken> get tokenChanges;

  /// Invalidates the device token for [transport] (used on sign-out, so the
  /// server can no longer reach this device for the old identity). The server
  /// also deletes a token it can no longer deliver to.
  Future<void> deleteToken(PushTransport transport);

  /// Encrypted gift-wrap payloads received while the app is **foregrounded**.
  /// (While backgrounded the OS routes them to the background isolate instead.)
  Stream<String> get foregroundMessages;
}
