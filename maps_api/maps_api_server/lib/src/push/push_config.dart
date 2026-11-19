import 'dart:io';

/// Server-side configuration for the Nostr → push forwarder.
///
/// The forwarder watches relays for events addressed to registered identities
/// and hands each one to a [PushSender]. Everything is overridable through the
/// environment so a deployment needs no code change:
///
/// * `PUSH_KINDS` — comma-separated outer kinds to watch (default `1059`).
/// * `PUSH_RELAYS` — comma-separated extra relays always watched.
/// * `PUSH_BOOTSTRAP_RELAY` — the single relay always watched.
class PushConfig {
  PushConfig._();

  /// Outer event kinds the forwarder subscribes to and can forward.
  ///
  /// `1059` (NIP-59 gift wrap) is the only kind the app's private notifications
  /// use: a live-share update, a DM or a feedback report all arrive wrapped, so
  /// the server only ever sees ciphertext. Public kinds (e.g. `1` or `7`) can be
  /// added and the server will gift-wrap them itself before sending, so FCM/APNs
  /// never see the plaintext either.
  static const List<int> defaultKinds = <int>[1059];

  /// A relay that is always watched, so an identity that registers only
  /// unreachable custom relays can still be reached.
  static const String defaultBootstrapRelay = 'wss://relay.map.camelus.app';

  /// Subscription id used on every relay connection. Chunked filters append
  /// `-<index>` (see [buildPushFilters]).
  static const String subscriptionId = 'openmaps-push';

  /// How many public keys one relay filter may carry. Relays cap a filter's
  /// value list, and `#p` filters with a few hundred entries are widely
  /// supported.
  static const int pubkeysPerFilter = 100;

  /// Events with more `p` tags than this are dropped (hellthread guard).
  static const int maxPubkeyPerEvent = 25;

  /// At most this many relays are kept per registration.
  static const int maxRelaysPerSubscription = 8;

  /// How long a single send (FCM or UnifiedPush) may take before it is aborted.
  static const Duration sendTimeout = Duration(seconds: 10);

  /// Event ids are remembered for this long to avoid duplicate pushes.
  static const Duration sentCacheTtl = Duration(minutes: 5);

  /// Upper bound on the dedup cache.
  static const int maxSentCacheSize = 5000;

  static List<int> get availableKinds {
    final String raw = Platform.environment['PUSH_KINDS']?.trim() ?? '';
    if (raw.isEmpty) {
      return defaultKinds;
    }
    final List<int> parsed = <int>[
      for (final String part in raw.split(','))
        if (int.tryParse(part.trim()) != null) int.parse(part.trim()),
    ];
    return parsed.isEmpty ? defaultKinds : parsed;
  }

  /// Every relay always watched: the bootstrap relay plus `PUSH_RELAYS`.
  static List<String> get bootstrapRelays {
    final Set<String> relays = <String>{
      Platform.environment['PUSH_BOOTSTRAP_RELAY']?.trim().isNotEmpty == true
          ? Platform.environment['PUSH_BOOTSTRAP_RELAY']!.trim()
          : defaultBootstrapRelay,
    };
    final String extra = Platform.environment['PUSH_RELAYS']?.trim() ?? '';
    for (final String part in extra.split(',')) {
      final String relay = part.trim();
      if (relay.startsWith('wss://') || relay.startsWith('ws://')) {
        relays.add(relay);
      }
    }
    return relays.toList(growable: false);
  }

  /// Relay-subscription filter: every available kind, no stored history.
  static Map<String, Object> get subscriptionFilter => <String, Object>{
    'kinds': availableKinds,
    'limit': 0,
  };
}
