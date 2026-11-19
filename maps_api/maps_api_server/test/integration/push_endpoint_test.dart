import 'package:maps_api_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import '../push/test_identity.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given the Push endpoint', (sessionBuilder, endpoints) {
    test('register then getState reports the relay and kinds', () async {
      final TestIdentity me = TestIdentity.generate();
      final String proof = await me.registration(token: 'fcm-token-1');

      expect(await endpoints.push.register(sessionBuilder, proof), isTrue);

      final state = await endpoints.push.getState(sessionBuilder, proof);
      expect(state.pubKey, me.pubKey);
      expect(state.availableKinds, contains(1059));
      expect(
        state.subscriptions.map((PushSubscriptionInfo s) => s.relay),
        contains('wss://relay.example.com'),
      );
    });

    test('registering the same token twice keeps one subscription', () async {
      final TestIdentity me = TestIdentity.generate();
      final String proof = await me.registration(token: 'fcm-token-1');

      await endpoints.push.register(sessionBuilder, proof);
      await endpoints.push.register(sessionBuilder, proof);

      final state = await endpoints.push.getState(sessionBuilder, proof);
      expect(state.subscriptions, hasLength(1));
    });

    test('a UnifiedPush token and a Firebase token coexist', () async {
      final TestIdentity me = TestIdentity.generate();
      await endpoints.push.register(
        sessionBuilder,
        await me.registration(token: 'fcm-token-1'),
      );
      await endpoints.push.register(
        sessionBuilder,
        await me.registration(
          token: 'https://ntfy.example.com/up/abc',
          relays: <String>['wss://relay.example.com'],
        ),
      );

      final state = await endpoints.push.getState(
        sessionBuilder,
        await me.registration(
          token: 'x',
          relays: <String>['wss://relay.example.com'],
        ),
      );
      expect(state.subscriptions, hasLength(1));
    });

    test('unregister removes the registration', () async {
      final TestIdentity me = TestIdentity.generate();
      final String proof = await me.registration(token: 'fcm-token-1');
      await endpoints.push.register(sessionBuilder, proof);

      expect(
        await endpoints.push.unregister(sessionBuilder, proof, 'fcm-token-1'),
        isTrue,
      );

      final state = await endpoints.push.getState(sessionBuilder, proof);
      expect(state.subscriptions, isEmpty);
    });
  });
}
