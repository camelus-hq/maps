import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';

/// Proves the privacy property the live-share friends list relies on, using the
/// real NDK set model and NIP-44 crypto (no network): a NIP-51 set written with
/// **private** elements exposes no friend public keys to a relay, and only the
/// owner can read them back.
void main() {
  Ndk buildNdk() => Ndk(
    NdkConfig(
      cache: MemCacheManager(),
      eventVerifier: Bip340EventVerifier(),
      bootstrapRelays: const <String>[],
    ),
  );

  const List<String> friends = <String>[
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  ];

  test(
    'the friends set keeps its keys encrypted in the event content',
    () async {
      final Ndk ndk = buildNdk();
      final KeyPair owner = Bip340.generatePrivateKey();
      ndk.accounts.loginPrivateKey(
        pubkey: owner.publicKey,
        privkey: owner.privateKey!,
      );

      final Nip51Set set = Nip51Set(
        name: 'friends',
        pubKey: owner.publicKey,
        kind: Nip51List.kFollowSet,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        elements: <Nip51ListElement>[
          for (final String key in friends)
            Nip51ListElement(tag: Nip51List.kPubkey, value: key, private: true),
        ],
      );

      final Nip01Event event = await set.toEvent(
        ndk.accounts.getLoggedAccount()?.signer,
      );

      // What a relay (and the world) sees.
      expect(event.kind, 30000);
      expect(
        event.tags.where((List<String> tag) => tag.isNotEmpty && tag[0] == 'd'),
        hasLength(1),
      );
      expect(
        event.tags.any((List<String> tag) => tag.isNotEmpty && tag[0] == 'p'),
        isFalse,
        reason: 'no friend public key may appear as a tag',
      );
      for (final String key in friends) {
        expect(event.content.contains(key), isFalse);
      }
      expect(
        event.content,
        isNotEmpty,
        reason: 'the keys are in the ciphertext',
      );

      // What the owner sees after reading it back.
      final Nip51Set? restored = await Nip51Set.fromEvent(
        event,
        ndk.accounts.getLoggedAccount()?.signer,
      );
      expect(restored, isNotNull);
      final List<String> visible = restored!.pubKeys
          .map((Nip51ListElement element) => element.value)
          .toList();
      expect(visible, containsAll(friends));
    },
  );

  test('someone else cannot read private set members', () async {
    final Ndk ndk = buildNdk();
    final KeyPair owner = Bip340.generatePrivateKey();
    final KeyPair stranger = Bip340.generatePrivateKey();

    ndk.accounts.loginPrivateKey(
      pubkey: owner.publicKey,
      privkey: owner.privateKey!,
    );
    final Nip01Event event = await Nip51Set(
      name: 'friends',
      pubKey: owner.publicKey,
      kind: Nip51List.kFollowSet,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      elements: <Nip51ListElement>[
        for (final String key in friends)
          Nip51ListElement(tag: Nip51List.kPubkey, value: key, private: true),
      ],
    ).toEvent(ndk.accounts.getLoggedAccount()?.signer);

    ndk.accounts.logout();
    ndk.accounts.loginPrivateKey(
      pubkey: stranger.publicKey,
      privkey: stranger.privateKey!,
    );

    final Nip51Set? asStranger = await Nip51Set.fromEvent(event, null);
    expect(asStranger, isNotNull);
    expect(asStranger!.pubKeys, isEmpty);
  });
}
