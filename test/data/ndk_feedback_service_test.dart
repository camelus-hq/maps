import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:openmaps/core/errors/app_exception.dart';
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

  test('sending while signed out asks to sign in', () async {
    final Ndk ndk = buildNdk();
    addTearDown(ndk.destroy);
    final NdkFeedbackService service = NdkFeedbackService(
      ndk: ndk,
      recipientPubkey: hex,
    );
    await expectLater(
      service.sendFeedback(message: 'hi', screenshot: png()),
      throwsA(isA<ValidationException>()),
    );
  });
}
