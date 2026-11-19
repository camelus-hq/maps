import 'dart:convert';

import 'package:maps_api_server/src/push/push_dispatcher.dart';
import 'package:maps_api_server/src/push/push_repository.dart';
import 'package:maps_api_server/src/push/push_sender.dart';
import 'package:test/test.dart';

import '../push/test_identity.dart';
import 'test_tools/serverpod_test_tools.dart';

void main() {
  withServerpod('Given the push dispatcher', (sessionBuilder, endpoints) {
    test('forwards a gift wrap for a registered recipient', () async {
      final TestIdentity me = TestIdentity.generate();
      await endpoints.push.register(
        sessionBuilder,
        await me.registration(token: 'fcm-token-1'),
      );

      final RecordingSender sender = RecordingSender('firebase');
      final PushDispatcher dispatcher = PushDispatcher(
        repository: const PushRepository(),
        senders: PushSenderRegistry(<PushSender>[sender]),
      );

      await dispatcher.dispatch(
        sessionBuilder.build(),
        TestIdentity.giftWrap(me.pubKey),
      );

      expect(sender.sent, hasLength(1));
      expect(sender.sent.single.token, 'fcm-token-1');
      final Map<String, dynamic> payload =
          jsonDecode(sender.sent.single.payload) as Map<String, dynamic>;
      expect(payload['kind'], 1059);
      final List<dynamic> tags = payload['tags'] as List<dynamic>;
      expect(
        tags.any(
          (dynamic tag) =>
              tag is List &&
              tag.length >= 2 &&
              tag[0] == 'p' &&
              tag[1] == me.pubKey,
        ),
        isTrue,
      );
    });

    test('ignores an event addressed to an unregistered identity', () async {
      final TestIdentity registered = TestIdentity.generate();
      final TestIdentity other = TestIdentity.generate();
      await endpoints.push.register(
        sessionBuilder,
        await registered.registration(token: 'fcm-token-1'),
      );

      final RecordingSender sender = RecordingSender('firebase');
      final PushDispatcher dispatcher = PushDispatcher(
        repository: const PushRepository(),
        senders: PushSenderRegistry(<PushSender>[sender]),
      );

      await dispatcher.dispatch(
        sessionBuilder.build(),
        TestIdentity.giftWrap(other.pubKey),
      );

      expect(sender.sent, isEmpty);
    });

    test('deletes a token the transport rejected', () async {
      final TestIdentity me = TestIdentity.generate();
      final String proof = await me.registration(token: 'fcm-token-1');
      await endpoints.push.register(sessionBuilder, proof);

      final RecordingSender sender = RecordingSender(
        'firebase',
        alwaysInvalid: true,
      );
      final PushDispatcher dispatcher = PushDispatcher(
        repository: const PushRepository(),
        senders: PushSenderRegistry(<PushSender>[sender]),
      );

      await dispatcher.dispatch(
        sessionBuilder.build(),
        TestIdentity.giftWrap(me.pubKey),
      );

      expect(sender.sent, hasLength(1));
      final state = await endpoints.push.getState(sessionBuilder, proof);
      expect(state.subscriptions, isEmpty);
    });
  });
}
