import 'dart:async';

import 'package:maps_api_server/src/generated/protocol.dart';
import 'package:maps_api_server/src/push/push.dart';
import 'package:maps_api_server/src/push/push_dispatcher.dart';
import 'package:maps_api_server/src/push/push_repository.dart';
import 'package:maps_api_server/src/push/push_sender.dart';
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

    test('a foreground stream pauses forwarding until it ends', () async {
      pushPresence.clear();
      addTearDown(pushPresence.clear);

      final TestIdentity me = TestIdentity.generate();
      await endpoints.push.register(
        sessionBuilder,
        await me.registration(token: 'fcm-token-1'),
      );

      final RecordingSender sender = RecordingSender('firebase');
      final PushDispatcher dispatcher = PushDispatcher(
        repository: const PushRepository(),
        senders: PushSenderRegistry(<PushSender>[sender]),
        presence: pushPresence,
      );

      final Stream<String> session = endpoints.push.foreground(
        sessionBuilder,
        await me.registration(token: 'proof'),
      );
      final StreamSubscription<String> sub = session.listen((String _) {});
      await _until(() => pushPresence.isActive(me.pubKey));

      await dispatcher.dispatch(
        sessionBuilder.build(),
        TestIdentity.giftWrap(me.pubKey),
      );
      expect(
        sender.sent,
        isEmpty,
        reason: 'the app is receiving the gift wrap itself',
      );

      // Backgrounding (or a socket timeout) cancels the stream; push resumes.
      await sub.cancel();
      await _until(() => !pushPresence.isActive(me.pubKey));

      await dispatcher.dispatch(
        sessionBuilder.build(),
        TestIdentity.giftWrap(me.pubKey),
      );
      expect(sender.sent, hasLength(1));
    });
  });
}

/// Polls [condition] until it holds, failing if it never does.
Future<void> _until(bool Function() condition) async {
  for (int i = 0; i < 200; i++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('condition was not met in time');
}
