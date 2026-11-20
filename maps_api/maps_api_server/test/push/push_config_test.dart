import 'package:maps_api_server/src/push/push_config.dart';
import 'package:test/test.dart';

void main() {
  group('PushConfig', () {
    test('the bootstrap relay is not an addressee-auth-gated #p relay', () {
      // The forwarder holds no user keys, so it cannot answer a relay that
      // requires the addressee's NIP-42 auth for a `#p` gift-wrap read (e.g.
      // relay.map.camelus.app): that relay closes the subscription with
      // `auth-required` and nothing is ever forwarded. The default bootstrap
      // must therefore be an openly readable relay.
      expect(
        PushConfig.defaultBootstrapRelay,
        isNot('wss://relay.map.camelus.app'),
        reason: 'the default bootstrap must be readable unauthenticated',
      );
      expect(PushConfig.defaultBootstrapRelay, startsWith('wss://'));
    });

    test('the ephemeral gift-wrap kind is never watchable', () {
      expect(
        PushConfig.availableKinds,
        isNot(contains(PushConfig.ephemeralGiftWrapKind)),
      );
    });
  });
}
