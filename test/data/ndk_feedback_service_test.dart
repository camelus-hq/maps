import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_anonymous_identity.dart';
import 'package:openmaps/data/nostr/ndk_feedback_service.dart';

/// The pure parts of the feedback adapter: recipient-key parsing and the quick
/// validation paths that must never touch a relay.
void main() {
  const String hex =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Ndk buildNdk() => Ndk(
    NdkConfig(
      cache: MemCacheManager(),
      eventVerifier: Bip340EventVerifier(),
      bootstrapRelays: const <String>[],
    ),
  );

  Uint8List png() => Uint8List.fromList(List<int>.filled(32, 7));

  group('normalizeRecipientPubkey', () {
    test('accepts hex, npub and nostr: forms', () {
      final String npub = Nip19.encodePubKey(hex);
      expect(NdkFeedbackService.normalizeRecipientPubkey(hex), hex);
      expect(NdkFeedbackService.normalizeRecipientPubkey('  $hex  '), hex);
      expect(NdkFeedbackService.normalizeRecipientPubkey(npub), hex);
      expect(NdkFeedbackService.normalizeRecipientPubkey('nostr:$npub'), hex);
      expect(
        NdkFeedbackService.normalizeRecipientPubkey(hex.toUpperCase()),
        hex,
      );
    });

    test('rejects anything that is not a public key', () {
      expect(NdkFeedbackService.normalizeRecipientPubkey(''), isNull);
      expect(NdkFeedbackService.normalizeRecipientPubkey('   '), isNull);
      expect(NdkFeedbackService.normalizeRecipientPubkey('not-a-key'), isNull);
      expect(
        NdkFeedbackService.normalizeRecipientPubkey('npub1notvalid'),
        isNull,
      );
      expect(NdkFeedbackService.normalizeRecipientPubkey('a' * 63), isNull);
    });
  });

  test(
    'an unconfigured recipient is unsupported, not a network call',
    () async {
      final Ndk ndk = buildNdk();
      addTearDown(ndk.destroy);
      final NdkFeedbackService service = NdkFeedbackService(
        ndk: ndk,
        recipientPubkey: '',
      );
      await expectLater(
        service.sendFeedback(message: 'hi', screenshot: png()),
        throwsA(isA<UnsupportedException>()),
      );
    },
  );

  test('reports the signed-in account as the sender', () async {
    final Ndk ndk = buildNdk();
    addTearDown(ndk.destroy);
    final KeyPair pair = Bip340.generatePrivateKey();
    ndk.accounts.loginPrivateKey(
      pubkey: pair.publicKey,
      privkey: pair.privateKey!,
    );
    final NdkFeedbackService service = NdkFeedbackService(
      ndk: ndk,
      recipientPubkey: hex,
      anonymousIdentity: FakeAnonymousIdentity(),
    );
    expect(await service.senderPubkey(), pair.publicKey);
  });

  test('falls back to the anonymous identity when signed out', () async {
    final Ndk ndk = buildNdk();
    addTearDown(ndk.destroy);
    final FakeAnonymousIdentity anonymous = FakeAnonymousIdentity();
    final NdkFeedbackService service = NdkFeedbackService(
      ndk: ndk,
      recipientPubkey: hex,
      anonymousIdentity: anonymous,
    );

    final String? sender = await service.senderPubkey();
    expect(sender, isNotNull);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(sender!), isTrue);
    // The same identity is reported on every call.
    expect(await service.senderPubkey(), sender);
    expect(anonymous.generated, 1);
  });

  test(
    'without an anonymous identity a send while signed out fails fast',
    () async {
      final Ndk ndk = buildNdk();
      addTearDown(ndk.destroy);
      final NdkFeedbackService service = NdkFeedbackService(
        ndk: ndk,
        recipientPubkey: hex,
      );
      expect(await service.senderPubkey(), isNull);
      await expectLater(
        service.sendFeedback(message: 'hi', screenshot: png()),
        throwsA(isA<ValidationException>()),
      );
    },
  );
}
