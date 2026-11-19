import 'dart:convert';

import 'package:maps_api_server/src/push/push_registration.dart';
import 'package:test/test.dart';

import 'test_identity.dart';

void main() {
  group('PushRegistration.parse', () {
    test('parses a Firebase registration', () async {
      final TestIdentity me = TestIdentity.generate();
      final PushRegistration registration = await PushRegistration.parse(
        await me.registration(token: 'fcm-token-123'),
      );

      expect(registration.pubKey, me.pubKey);
      expect(registration.token, 'fcm-token-123');
      expect(registration.transport, PushRegistration.transportFirebase);
      expect(registration.relays, <String>['wss://relay.example.com']);
      expect(registration.kinds, <int>[1059]);
    });

    test('a URL token selects the UnifiedPush transport', () async {
      final TestIdentity me = TestIdentity.generate();
      final PushRegistration registration = await PushRegistration.parse(
        await me.registration(token: 'https://ntfy.example.com/up/abc'),
      );

      expect(registration.transport, PushRegistration.transportUnifiedPush);
    });

    test('only keeps ws/wss relays and de-duplicates', () async {
      final TestIdentity me = TestIdentity.generate();
      final PushRegistration registration = await PushRegistration.parse(
        await me.registration(
          token: 'tok',
          relays: <String>[
            'http://evil.example.com',
            'wss://relay.example.com',
            'wss://relay.example.com',
            'wss://second.example.com',
          ],
        ),
      );

      expect(registration.relays, <String>[
        'wss://relay.example.com',
        'wss://second.example.com',
      ]);
    });

    test('falls back to the available kinds when none are supported', () async {
      final TestIdentity me = TestIdentity.generate();
      final PushRegistration registration = await PushRegistration.parse(
        await me.registration(token: 'tok', kinds: <int>[1]),
      );

      expect(registration.kinds, contains(1059));
    });

    test('rejects a tampered event', () async {
      final TestIdentity me = TestIdentity.generate();
      final String json = await me.registration(token: 'tok');
      final Map<String, dynamic> map = jsonDecode(json) as Map<String, dynamic>;
      map['content'] = 'tampered';

      expect(
        () => PushRegistration.parse(jsonEncode(map)),
        throwsA(isA<PushRegistrationException>()),
      );
    });

    test('rejects an event without a push token', () async {
      final TestIdentity me = TestIdentity.generate();
      final String json = await me.sign(
        tags: <List<String>>[
          <String>['relay', 'wss://relay.example.com'],
        ],
      );

      expect(
        () => PushRegistration.parse(json),
        throwsA(isA<PushRegistrationException>()),
      );
    });

    test('rejects an event without relays', () async {
      final TestIdentity me = TestIdentity.generate();
      final String json = await me.sign(
        tags: <List<String>>[
          <String>['push-token', 'tok'],
        ],
      );

      expect(
        () => PushRegistration.parse(json),
        throwsA(isA<PushRegistrationException>()),
      );
    });

    test('rejects malformed JSON', () async {
      expect(
        () => PushRegistration.parse('not json'),
        throwsA(isA<PushRegistrationException>()),
      );
    });
  });
}
