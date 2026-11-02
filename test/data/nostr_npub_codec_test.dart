import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_flutter/ndk_flutter.dart';
import 'package:openmaps/data/nostr/ndk_social_service.dart';

/// The npub codec behind the "My code" QR: what we let a friend scan must be
/// the same key we accept back when they paste or scan it.
void main() {
  const String hex =
      'da1678cd43b0afed5c5566b878a0a5faae97b16635b47d58b9179a75de500801';

  NdkSocialService buildService() {
    final Ndk ndk = Ndk.emptyBootstrapRelaysConfig();
    return NdkSocialService(
      ndk: ndk,
      ndkFlutter: NdkFlutter(ndk: ndk),
    );
  }

  test('hex keys encode to npub and round-trip', () {
    final NdkSocialService service = buildService();

    final String? npub = service.encodeNpub(hex);
    expect(npub, isNotNull);
    expect(npub!.startsWith('npub1'), isTrue);
    expect(service.normalizePubkey(npub), hex);
    expect(service.normalizePubkey('nostr:$npub'), hex);
    expect(service.normalizePubkey('  ${npub.toUpperCase()}  '), hex);
  });

  test('hex keys are accepted directly and hostile input is rejected', () {
    final NdkSocialService service = buildService();

    expect(service.normalizePubkey(hex.toUpperCase()), hex);
    expect(service.normalizePubkey(''), isNull);
    expect(service.normalizePubkey('npub1notavalidkey'), isNull);
    expect(service.normalizePubkey('x' * 64), isNull);
    expect(service.normalizePubkey('https://example.com'), isNull);
    expect(service.encodeNpub('not-a-key'), isNull);
  });
}
