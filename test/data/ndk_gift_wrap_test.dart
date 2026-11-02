import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:openmaps/data/nostr/live_location_payload.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/live_share.dart';

/// Exercises the real NIP-59 gift-wrap crypto the live-share adapter relies on,
/// entirely in-process (two identities, no relays): the sender seals and wraps
/// our payload for a friend, the friend unwraps and decrypts it, and anyone
/// else cannot.
void main() {
  Ndk buildNdk() => Ndk(
    NdkConfig(
      cache: MemCacheManager(),
      eventVerifier: Bip340EventVerifier(),
      bootstrapRelays: const <String>[],
    ),
  );

  void signIn(Ndk ndk, KeyPair pair) {
    final String? privkey = pair.privateKey;
    expect(privkey, isNotNull);
    ndk.accounts.loginPrivateKey(pubkey: pair.publicKey, privkey: privkey!);
  }

  test('a live-location payload survives a gift wrap to a friend', () async {
    final Ndk ndk = buildNdk();
    final KeyPair sender = Bip340.generatePrivateKey();
    final KeyPair friend = Bip340.generatePrivateKey();

    final DateTime now = DateTime.now();
    final LiveShareBroadcast broadcast = LiveShareBroadcast(
      sessionId: 'session-42',
      kind: LiveShareBroadcastKind.update,
      position: const LatLon(52.52, 13.405),
      sampledAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
      accuracyMeters: 9,
      heading: 180,
    );

    signIn(ndk, sender);
    final String? me = ndk.accounts.getPublicKey();
    expect(me, sender.publicKey);

    final Nip01Event rumor = await ndk.giftWrap.createRumor(
      customPubkey: me,
      kind: LiveLocationPayload.rumorKind,
      content: LiveLocationPayload.encode(broadcast),
      tags: <List<String>>[
        <String>['p', friend.publicKey],
        <String>['t', LiveLocationPayload.featureTag],
        <String>['d', broadcast.sessionId],
      ],
    );
    final Nip01Event wrap = await ndk.giftWrap.toGiftWrap(
      rumor: rumor,
      recipientPubkey: friend.publicKey,
    );

    // The relay-visible envelope is opaque: no coordinates, no sender.
    expect(wrap.kind, 1059);
    expect(wrap.content.contains('52.52'), isFalse);
    expect(wrap.pubKey, isNot(sender.publicKey));
    expect(
      wrap.tags.any(
        (List<String> tag) => tag.length > 1 && tag[1] == friend.publicKey,
      ),
      isTrue,
    );

    // The friend opens it.
    ndk.accounts.logout();
    signIn(ndk, friend);
    final Nip01Event unwrapped = await ndk.giftWrap.fromGiftWrap(
      giftWrap: wrap,
    );
    expect(unwrapped.kind, LiveLocationPayload.rumorKind);
    expect(unwrapped.pubKey, sender.publicKey);

    final LiveLocationPayload? payload = LiveLocationPayload.decode(
      unwrapped.content,
    );
    expect(payload, isNotNull);
    expect(payload!.isStop, isFalse);
    expect(payload.sessionId, 'session-42');
    expect(payload.position, const LatLon(52.52, 13.405));
    expect(payload.accuracyMeters, 9);
    expect(payload.heading, 180);
  });

  test('a bystander cannot read the wrapped share', () async {
    final Ndk ndk = buildNdk();
    final KeyPair sender = Bip340.generatePrivateKey();
    final KeyPair friend = Bip340.generatePrivateKey();
    final KeyPair bystander = Bip340.generatePrivateKey();

    signIn(ndk, sender);
    final Nip01Event rumor = await ndk.giftWrap.createRumor(
      kind: LiveLocationPayload.rumorKind,
      content: LiveLocationPayload.encode(
        LiveShareBroadcast(
          sessionId: 's',
          kind: LiveShareBroadcastKind.update,
          position: const LatLon(1, 2),
          sampledAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        ),
      ),
      tags: <List<String>>[
        <String>['p', friend.publicKey],
      ],
    );
    final Nip01Event wrap = await ndk.giftWrap.toGiftWrap(
      rumor: rumor,
      recipientPubkey: friend.publicKey,
    );

    ndk.accounts.logout();
    signIn(ndk, bystander);
    await expectLater(
      ndk.giftWrap.fromGiftWrap(giftWrap: wrap),
      throwsA(anything),
    );
  });
}
