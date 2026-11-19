import 'package:maps_api_client/maps_api_client.dart';

import '../../domain/entities/push.dart';
import '../../domain/ports/social_service.dart';

/// The server side of a push registration (the Serverpod `push` endpoint).
///
/// Behind an interface so the registration flow can be tested without a server
/// and faked in keyless runs.
abstract interface class PushRegistrationApi {
  /// Sends a signed registration event.
  Future<bool> register(String signedEventJson);

  /// Removes the identity's registration, or only [token]'s when given.
  Future<bool> unregister(String signedEventJson, {String? token});

  /// Opens a server-side **foreground session** for the identity behind
  /// [signedEventJson]: while the returned stream stays open the server pauses
  /// forwarding to the identity (the app is receiving gift wraps itself). The
  /// stream ends when the subscription is cancelled or the socket times out.
  Stream<String> foreground(String signedEventJson);
}

/// [PushRegistrationApi] over the generated Serverpod client.
class ServerpodPushRegistrationApi implements PushRegistrationApi {
  ServerpodPushRegistrationApi(this._client);

  final Client _client;

  @override
  Future<bool> register(String signedEventJson) =>
      _client.push.register(signedEventJson);

  @override
  Future<bool> unregister(String signedEventJson, {String? token}) =>
      _client.push.unregister(signedEventJson, token);

  @override
  Stream<String> foreground(String signedEventJson) =>
      _client.push.foreground(signedEventJson);
}

/// Builds and sends a **signed** push registration.
///
/// The server is told the token, the transport, the relays it should watch and
/// the outer kinds to forward; the signature proves the identity, so the token
/// is bound to the public key.
class PushRegistrar {
  const PushRegistrar({
    required this.social,
    required this.api,
    required this.relays,
    this.kinds = const <int>[1059],
  });

  final SocialService social;
  final PushRegistrationApi api;

  /// Relays the server should watch for this identity.
  final List<String> relays;

  /// Outer kinds to forward (1059 = NIP-59 gift wrap).
  final List<int> kinds;

  /// The (ephemeral) kind used for the signed proof event.
  static const int proofKind = 22242;

  /// Registers [token] for [transport]. Returns `false` when signed out,
  /// disabled, or the server rejected it.
  Future<bool> register({
    required String token,
    required PushTransport transport,
  }) async {
    if (!transport.isEnabled || token.trim().isEmpty) {
      return false;
    }
    final String? proof = await social.signEvent(
      kind: proofKind,
      tags: _tags(token: token, transport: transport),
    );
    if (proof == null) {
      return false;
    }
    return api.register(proof);
  }

  /// Removes the registration (or just [token]'s). A no-op when signed out.
  Future<bool> unregister({String? token}) async {
    final String? proof = await social.signEvent(
      kind: proofKind,
      tags: const <List<String>>[],
    );
    if (proof == null) {
      return false;
    }
    return api.unregister(proof, token: token);
  }

  /// Opens a **foreground session** with the server: while the returned stream
  /// is open, the server pauses forwarding to this identity because the app is
  /// receiving gift wraps on its own relay subscription.
  ///
  /// Returns an empty stream when signed out (nothing to pause).
  Future<Stream<String>> foreground() async {
    final String? proof = await social.signEvent(
      kind: proofKind,
      tags: const <List<String>>[],
    );
    if (proof == null) {
      return const Stream<String>.empty();
    }
    return api.foreground(proof);
  }

  List<List<String>> _tags({
    required String token,
    required PushTransport transport,
  }) => <List<String>>[
    <String>['push-token', token.trim()],
    <String>['push-transport', transport.wire],
    for (final String relay in relays) <String>['relay', relay],
    for (final int kind in kinds) <String>['kind', '$kind'],
  ];
}
