import 'dart:convert';

import 'package:ndk/ndk.dart' as ndk;

import 'push_config.dart';

/// Thrown when a signed registration/proof event is malformed, unsigned, or
/// does not carry the tags a push registration needs.
class PushRegistrationException implements Exception {
  const PushRegistrationException(this.message);

  final String message;

  @override
  String toString() => 'PushRegistrationException: $message';
}

/// The parsed, verified content of a push registration.
///
/// A client proves ownership of its Nostr identity by signing an event and
/// putting the push token and relay/kind routing in its tags. Nothing here is
/// trusted until [parse] has verified the signature.
class PushRegistration {
  const PushRegistration({
    required this.pubKey,
    required this.token,
    required this.transport,
    required this.relays,
    required this.kinds,
  });

  /// The owner of the identity (lowercase hex), from the signed event.
  final String pubKey;

  /// The push destination: an FCM registration token or a UnifiedPush URL.
  final String token;

  /// `firebase` for an FCM token, `unifiedpush` for an endpoint URL. Derived
  /// from the token shape, so a client simply supplies the right kind of token.
  final String transport;

  /// The relays the identity wants to be watched on (already filtered).
  final List<String> relays;

  /// The outer kinds requested (already intersected with what the server
  /// forwards; never empty).
  final List<int> kinds;

  /// Tag naming the push token. `challenge` is accepted as a legacy alias.
  static const String tokenTag = 'push-token';
  static const String tokenTagLegacy = 'challenge';

  /// Tag naming the transport (`firebase` / `unifiedpush`). Optional; the token
  /// shape is authoritative.
  static const String transportTag = 'push-transport';

  /// Tag naming a relay the identity can be reached on (repeated).
  static const String relayTag = 'relay';

  /// Tag naming an outer kind to push (repeated).
  static const String kindTag = 'kind';

  static const String transportFirebase = 'firebase';
  static const String transportUnifiedPush = 'unifiedpush';

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  /// Parses and verifies a signed event, returning the registration it carries.
  static Future<PushRegistration> parse(String signedEventJson) async {
    final ndk.Nip01EventModel event = await verifyEvent(signedEventJson);
    final String pubKey = event.pubKey.toLowerCase();

    final String? token =
        _firstTag(event, tokenTag) ?? _firstTag(event, tokenTagLegacy);
    if (token == null || token.isEmpty) {
      throw const PushRegistrationException('Missing push token');
    }
    if (token.length > 4096) {
      throw const PushRegistrationException('Push token is too long');
    }

    final String transport = transportForToken(token);
    final String? declared = _firstTag(event, transportTag)?.toLowerCase();
    if (declared != null &&
        declared.isNotEmpty &&
        declared != transportFirebase &&
        declared != transportUnifiedPush) {
      throw PushRegistrationException('Unknown transport: $declared');
    }

    final List<String> relays = <String>[];
    for (final List<String> tag in event.tags) {
      if (tag.length < 2 || tag[0] != relayTag) {
        continue;
      }
      final String relay = tag[1].trim();
      if (!_isRelayUrl(relay) || relays.contains(relay)) {
        continue;
      }
      relays.add(relay);
      if (relays.length >= PushConfig.maxRelaysPerSubscription) {
        break;
      }
    }
    if (relays.isEmpty) {
      throw const PushRegistrationException('No relays in registration');
    }

    final Set<int> available = PushConfig.availableKinds.toSet();
    final Set<int> kinds = <int>{
      for (final List<String> tag in event.tags)
        if (tag.length >= 2 && tag[0] == kindTag)
          if (int.tryParse(tag[1]) != null &&
              available.contains(int.parse(tag[1])))
            int.parse(tag[1]),
    };
    if (kinds.isEmpty) {
      kinds.addAll(available);
    }

    return PushRegistration(
      pubKey: pubKey,
      token: token,
      transport: transport,
      relays: relays,
      kinds: kinds.toList(growable: false),
    );
  }

  /// Verifies the signature of a proof event and returns the public key.
  ///
  /// Used by `getState`/`unregister`, which prove identity but need no token.
  static Future<String> verifyPubKey(String signedEventJson) async =>
      (await verifyEvent(signedEventJson)).pubKey.toLowerCase();

  /// Decodes and BIP-340-verifies a signed event, rejecting anything forged,
  /// tampered with, or not a well-formed Nostr event.
  static Future<ndk.Nip01EventModel> verifyEvent(String signedEventJson) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(signedEventJson);
    } on FormatException catch (error) {
      throw PushRegistrationException('Not valid JSON: ${error.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PushRegistrationException('Event is not a JSON object');
    }

    final ndk.Nip01EventModel event;
    try {
      event = ndk.Nip01EventModel.fromJson(decoded);
    } catch (error) {
      throw PushRegistrationException('Not a Nostr event: $error');
    }

    final String pubKey = event.pubKey.toLowerCase();
    if (!_hexPubkey.hasMatch(pubKey)) {
      throw const PushRegistrationException('Missing or invalid public key');
    }

    final ndk.Bip340EventVerifier verifier = ndk.Bip340EventVerifier(
      useIsolate: false,
    );
    final bool valid;
    try {
      valid = await verifier.verify(event);
    } catch (error) {
      throw PushRegistrationException('Signature check failed: $error');
    }
    if (!valid) {
      throw const PushRegistrationException('Invalid event signature');
    }
    return event;
  }

  /// The transport implied by [token]: a URL is a UnifiedPush endpoint,
  /// anything else is an FCM registration token.
  static String transportForToken(String token) =>
      (token.startsWith('https://') || token.startsWith('http://'))
      ? transportUnifiedPush
      : transportFirebase;

  static String? _firstTag(ndk.Nip01Event event, String name) {
    for (final List<String> tag in event.tags) {
      if (tag.length >= 2 && tag[0] == name && tag[1].trim().isNotEmpty) {
        return tag[1].trim();
      }
    }
    return null;
  }

  static bool _isRelayUrl(String url) {
    if (!url.startsWith('wss://') && !url.startsWith('ws://')) {
      return false;
    }
    return url.length <= 512 && !url.contains(RegExp(r'\s'));
  }
}
