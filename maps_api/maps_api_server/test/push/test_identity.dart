import 'package:maps_api_server/src/push/push_config.dart';
import 'package:maps_api_server/src/push/push_sender.dart';
import 'package:ndk/ndk.dart' as ndk;

/// A throwaway Nostr identity for tests: generates a key pair, signs events and
/// builds the signed registrations the endpoint/protocol expect.
class TestIdentity {
  TestIdentity._(this._signer, this.pubKey);

  final ndk.Bip340EventSigner _signer;
  final String pubKey;

  factory TestIdentity.generate() {
    const ndk.Bip340EventSignerFactory factory = ndk.Bip340EventSignerFactory();
    final (String privateKey, String publicKey) = factory.generateKeyPair();
    return TestIdentity._(
      ndk.Bip340EventSigner(privateKey: privateKey, publicKey: publicKey),
      publicKey,
    );
  }

  /// Signs an event with this identity and returns its JSON.
  Future<String> sign({
    required List<List<String>> tags,
    int kind = 22242,
    String content = '',
  }) async {
    final ndk.Nip01Event event = ndk.Nip01Event(
      pubKey: pubKey,
      kind: kind,
      tags: tags,
      content: content,
    );
    final ndk.Nip01Event signed = await _signer.sign(event);
    return ndk.Nip01EventModel.fromEntity(signed).toJsonString();
  }

  /// A signed push registration with the given [token], [relays] and [kinds].
  Future<String> registration({
    required String token,
    List<String> relays = const <String>['wss://relay.example.com'],
    List<int> kinds = const <int>[1059],
    String? transport,
  }) => sign(
    tags: <List<String>>[
      <String>['push-token', token],
      if (transport != null) <String>['push-transport', transport],
      for (final String relay in relays) <String>['relay', relay],
      for (final int kind in kinds) <String>['kind', '$kind'],
    ],
  );

  /// A kind-1059 event addressed to [recipient]. The content is opaque to the
  /// server, so it need not be a real ciphertext.
  static ndk.Nip01EventModel giftWrap(String recipient) =>
      ndk.Nip01EventModel.fromEntity(
        ndk.Nip01Event(
          pubKey: 'f' * 64,
          kind: ndk.GiftWrap.kGiftWrapEventkind,
          tags: <List<String>>[
            <String>['p', recipient],
          ],
          content: 'opaque-ciphertext',
        ),
      );

  /// A kind-21059 **ephemeral** gift wrap addressed to [recipient], as a
  /// live-share position update arrives. The server must never forward it.
  static ndk.Nip01EventModel ephemeralGiftWrap(String recipient) =>
      ndk.Nip01EventModel.fromEntity(
        ndk.Nip01Event(
          pubKey: 'f' * 64,
          kind: PushConfig.ephemeralGiftWrapKind,
          tags: <List<String>>[
            <String>['p', recipient],
          ],
          content: 'opaque-ciphertext',
        ),
      );
}

/// A [PushSender] that records what it was asked to send.
class RecordingSender implements PushSender {
  RecordingSender(this.transport, {this.alwaysInvalid = false});

  @override
  final String transport;

  /// When true, every send reports the token as dead.
  final bool alwaysInvalid;

  final List<({String token, String payload})> sent =
      <({String token, String payload})>[];

  @override
  Future<PushSendResult> send(String token, String encryptedEventJson) async {
    sent.add((token: token, payload: encryptedEventJson));
    if (alwaysInvalid) {
      return const PushSendResult.failure(
        invalidToken: true,
        error: 'gone',
      );
    }
    return const PushSendResult.success();
  }
}
