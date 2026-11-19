/// How a device is reached by the push server.
///
/// [off] is a stored preference that disables push; [firebase] is the live
/// transport. (The server also accepts UnifiedPush endpoints, but the app does
/// not use that transport yet.)
enum PushTransport {
  firebase,
  off;

  /// Whether this preference wants push at all.
  bool get isEnabled => this != off;

  /// The value the server protocol uses (`firebase` / `off`).
  String get wire => switch (this) {
    PushTransport.firebase => 'firebase',
    PushTransport.off => 'off',
  };

  /// Reads a stored preference, defaulting to [PushTransport.firebase].
  static PushTransport fromStorage(String? value) => switch (value) {
    'off' => PushTransport.off,
    _ => PushTransport.firebase,
  };
}

/// A device token for one transport — an FCM registration token.
class PushToken {
  const PushToken({required this.transport, required this.value});

  final PushTransport transport;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is PushToken &&
      other.transport == transport &&
      other.value == value;

  @override
  int get hashCode => Object.hash(transport, value);
}

/// The user-visible state of push for this device, shown in settings.
class PushStatus {
  const PushStatus({
    this.serverConfigured = false,
    this.supported = false,
    this.transport = PushTransport.firebase,
    this.permissionGranted = false,
    this.hasToken = false,
    this.registered = false,
    this.error,
  });

  /// Whether this build points at a push backend (`PUSH_SERVER_URL`).
  final bool serverConfigured;

  /// Whether the platform/build can receive push at all.
  final bool supported;

  /// The selected transport.
  final PushTransport transport;

  /// Whether OS notification permission is granted.
  final bool permissionGranted;

  /// Whether a device token is available.
  final bool hasToken;

  /// Whether the server accepted the registration.
  final bool registered;

  /// A last error, surfaced in settings.
  final String? error;

  PushStatus copyWith({
    bool? serverConfigured,
    bool? supported,
    PushTransport? transport,
    bool? permissionGranted,
    bool? hasToken,
    bool? registered,
    String? error,
    bool clearError = false,
  }) => PushStatus(
    serverConfigured: serverConfigured ?? this.serverConfigured,
    supported: supported ?? this.supported,
    transport: transport ?? this.transport,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    hasToken: hasToken ?? this.hasToken,
    registered: registered ?? this.registered,
    error: clearError ? null : (error ?? this.error),
  );
}

/// A push gift wrap that was decrypted into the event it carries.
///
/// The server only ever sees ciphertext; this is the rumor extracted on-device
/// (a live-share update, a direct message, …).
class DecryptedPushEvent {
  const DecryptedPushEvent({
    required this.kind,
    required this.content,
    required this.senderPubkey,
  });

  final int kind;
  final String content;
  final String senderPubkey;
}
