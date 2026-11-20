import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:openmaps/data/nostr/live_location_payload.dart';
import 'package:openmaps/data/nostr/live_share_wire.dart';
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
    // A position update is ephemeral: it travels in a kind-21059 wrap.
    final Nip01Event wrap = await ndk.giftWrap.toGiftWrap(
      rumor: rumor,
      recipientPubkey: friend.publicKey,
      ephemeral: isEphemeralLiveShare(broadcast.kind),
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    // The relay-visible envelope is opaque: no coordinates, no sender.
    expect(wrap.kind, 21059);
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
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    ndk.accounts.logout();
    signIn(ndk, bystander);
    await expectLater(
      ndk.giftWrap.fromGiftWrap(giftWrap: wrap),
      throwsA(anything),
    );
  });

  test('only a position update is ephemeral; start and stop are stored', () {
    expect(isEphemeralLiveShare(LiveShareBroadcastKind.update), isTrue);
    expect(isEphemeralLiveShare(LiveShareBroadcastKind.start), isFalse);
    expect(isEphemeralLiveShare(LiveShareBroadcastKind.stop), isFalse);
  });

  test('the live subscription watches both the stored and ephemeral wrap', () {
    final Filter filter = liveLocationFilter('a' * 64, since: 100);

    expect(
      filter.kinds,
      containsAll(<int>[
        GiftWrap.kGiftWrapEventkind,
        GiftWrap.kEphemeralGiftWrapEventKind,
      ]),
    );
    expect(filter.kinds, hasLength(2));
    expect(filter.pTags, <String>['a' * 64]);
    // Live-only: never replay stored events.
    expect(filter.limit, 0);
  });

  test('start and stop travel stored (1059); an update is ephemeral (21059)', () async {
    final Ndk ndk = buildNdk();
    final KeyPair sender = Bip340.generatePrivateKey();
    final KeyPair friend = Bip340.generatePrivateKey();
    signIn(ndk, sender);
    final String? me = ndk.accounts.getPublicKey();

    Future<Nip01Event> wrapFor(LiveShareBroadcastKind kind) async {
      final DateTime now = DateTime.now();
      final LiveShareBroadcast broadcast = LiveShareBroadcast(
        sessionId: 'session-1',
        kind: kind,
        position: kind == LiveShareBroadcastKind.stop
            ? null
            : const LatLon(52.52, 13.405),
        sampledAt: now,
        expiresAt: now.add(const Duration(minutes: 30)),
      );
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
      // The exact arguments NdkSocialService.publishLiveShare uses: the outer
      // kind follows the broadcast, and `createdAt` is "now" so a relay does
      // not reject a stored wrap whose randomized NIP-59 timestamp looks old.
      return ndk.giftWrap.toGiftWrap(
        rumor: rumor,
        recipientPubkey: friend.publicKey,
        ephemeral: isEphemeralLiveShare(broadcast.kind),
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    }

    final Nip01Event start = await wrapFor(LiveShareBroadcastKind.start);
    final Nip01Event stop = await wrapFor(LiveShareBroadcastKind.stop);
    final Nip01Event update = await wrapFor(LiveShareBroadcastKind.update);

    // The outer kinds: start/stop are stored and therefore forwardable; the
    // update is ephemeral and never forwarded.
    expect(start.kind, 1059);
    expect(stop.kind, 1059);
    expect(update.kind, 21059);

    // A stored wrap must look current, or a relay drops it as too old and it
    // is never actually published.
    final int nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final Nip01Event stored in <Nip01Event>[start, stop]) {
      expect(
        (stored.createdAt - nowSeconds).abs() <= 5,
        isTrue,
        reason: 'a stored wrap needs a current created_at to be accepted',
      );
      // The `#p` tag is what the recipient's client and the push server filter
      // on, so a stored wrap is only useful if it carries the recipient.
      expect(
        stored.tags.any(
          (List<String> tag) =>
              tag.length >= 2 && tag[0] == 'p' && tag[1] == friend.publicKey,
        ),
        isTrue,
      );
    }
  });

  test('a stored start actually unwraps to the start rumor', () async {
    final Ndk ndk = buildNdk();
    final KeyPair sender = Bip340.generatePrivateKey();
    final KeyPair friend = Bip340.generatePrivateKey();
    signIn(ndk, sender);
    final String? me = ndk.accounts.getPublicKey();
    final DateTime now = DateTime.now();

    final LiveShareBroadcast broadcast = LiveShareBroadcast(
      sessionId: 'session-9',
      kind: LiveShareBroadcastKind.start,
      position: const LatLon(52.52, 13.405),
      sampledAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
    );
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
      ephemeral: isEphemeralLiveShare(broadcast.kind),
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    expect(wrap.kind, 1059);

    // The recipient opens the stored wrap and sees a start.
    ndk.accounts.logout();
    signIn(ndk, friend);
    final Nip01Event unwrapped = await ndk.giftWrap.fromGiftWrap(
      giftWrap: wrap,
    );
    expect(unwrapped.kind, LiveLocationPayload.rumorKind);
    final LiveLocationPayload? payload = LiveLocationPayload.decode(
      unwrapped.content,
    );
    expect(payload, isNotNull);
    expect(payload!.isStart, isTrue);
    expect(payload.isStop, isFalse);
    expect(payload.sessionId, 'session-9');
  });
}
