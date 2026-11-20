import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_push_registration_api.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/data/notifications/push_registrar.dart';
import 'package:openmaps/domain/entities/push.dart';

List<List<String>> _tagsOf(String signedEventJson) {
  final Map<String, dynamic> event =
      jsonDecode(signedEventJson) as Map<String, dynamic>;
  return (event['tags'] as List<dynamic>)
      .map((dynamic tag) => (tag as List<dynamic>).cast<String>())
      .toList();
}

void main() {
  group('PushRegistrar', () {
    test('registers a signed event with token, transport and relays', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrar registrar = PushRegistrar(
        social: social,
        api: api,
        relays: const <String>['wss://relay.example.com'],
      );

      final bool ok = await registrar.register(
        token: 'fcm-token-1',
        transport: PushTransport.firebase,
      );

      expect(ok, isTrue);
      expect(api.registrations, hasLength(1));
      final List<List<String>> tags = _tagsOf(api.registrations.single);
      expect(
        tags.any(
          (List<String> t) => t[0] == 'push-token' && t[1] == 'fcm-token-1',
        ),
        isTrue,
      );
      expect(
        tags.any(
          (List<String> t) => t[0] == 'push-transport' && t[1] == 'firebase',
        ),
        isTrue,
      );
      expect(
        tags.any(
          (List<String> t) =>
              t[0] == 'relay' && t[1] == 'wss://relay.example.com',
        ),
        isTrue,
      );
    });

    test('does not register when signed out', () async {
      final FakeSocialService social = FakeSocialService(signedIn: false);
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrar registrar = PushRegistrar(
        social: social,
        api: api,
        relays: const <String>[],
      );

      expect(
        await registrar.register(
          token: 'fcm-token-1',
          transport: PushTransport.firebase,
        ),
        isFalse,
      );
      expect(api.registrations, isEmpty);
    });

    test('does not register when push is off', () async {
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrar registrar = PushRegistrar(
        social: FakeSocialService(),
        api: api,
        relays: const <String>[],
      );

      expect(
        await registrar.register(token: 'x', transport: PushTransport.off),
        isFalse,
      );
      expect(api.registrations, isEmpty);
    });

    test('unregisters with a signed proof', () async {
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrar registrar = PushRegistrar(
        social: FakeSocialService(),
        api: api,
        relays: const <String>[],
      );

      expect(await registrar.unregister(token: 'fcm-token-1'), isTrue);
      expect(api.unregistrations, hasLength(1));
      expect(api.unregistrations.single.token, 'fcm-token-1');
    });
  });
}
