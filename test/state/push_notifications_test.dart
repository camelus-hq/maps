import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_push_messaging.dart';
import 'package:openmaps/data/fakes/fake_push_notifications.dart';
import 'package:openmaps/data/fakes/fake_push_registration_api.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/data/notifications/push_registrar.dart';
import 'package:openmaps/domain/entities/push.dart';
import 'package:openmaps/state/push_notifications.dart';

void main() {
  group('PushRegistrationBootstrap', () {
    test('registers a signed-in device on start', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>['wss://relay.example.com'],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(messaging.initialized, isTrue);
      expect(messaging.permissionRequests, greaterThan(0));
      expect(api.registrations, hasLength(1));
      expect(bootstrap.status.value.registered, isTrue);
      expect(bootstrap.status.value.hasToken, isTrue);

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('unregisters when the user signs out', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: FakePushRegistrationApi(),
          relays: const <String>['wss://relay.example.com'],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();
      await social.logout();
      await pumpEventQueue();

      expect(messaging.deletedTokens, contains(PushTransport.firebase));
      expect(bootstrap.status.value.registered, isFalse);

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('does not register when push is off', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        transport: PushTransport.off,
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(api.registrations, isEmpty);

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('does not register when no backend is configured', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
      );

      await bootstrap.start();

      expect(api.registrations, isEmpty);

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('registers a token that only arrives after start', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging();
      final FakePushRegistrationApi api = FakePushRegistrationApi();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();
      expect(api.registrations, isEmpty);

      // FCM delivers the token after the initial sync already gave up waiting.
      messaging.setToken(PushTransport.firebase, 'late-token');
      await pumpEventQueue();

      expect(api.registrations, hasLength(1));
      expect(bootstrap.status.value.registered, isTrue);
      expect(bootstrap.status.value.hasToken, isTrue);
      expect(bootstrap.status.value.error, isNull);

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('surfaces the transport reason when no token is available', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging()
        ..lastError = 'Firebase is not configured for this build';
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: FakePushRegistrationApi(),
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(bootstrap.status.value.hasToken, isFalse);
      expect(bootstrap.status.value.registered, isFalse);
      expect(
        bootstrap.status.value.error,
        contains('Firebase is not configured'),
      );

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('tells a signed-out user to sign in', () async {
      final FakeSocialService social = FakeSocialService(signedIn: false);
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: FakePushRegistrationApi(),
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(bootstrap.status.value.registered, isFalse);
      expect(bootstrap.status.value.error, contains('Sign in'));

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('reports a server refusal', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushRegistrationApi api = FakePushRegistrationApi(
        result: false,
      );
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(bootstrap.status.value.hasToken, isTrue);
      expect(bootstrap.status.value.registered, isFalse);
      expect(bootstrap.status.value.error, contains('rejected'));

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('reports an unreachable server instead of throwing', () async {
      final FakeSocialService social = FakeSocialService();
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushRegistrationApi api = FakePushRegistrationApi(
        registerError: Exception('connection refused'),
      );
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: api,
          relays: const <String>[],
        ),
        social: social,
        notifications: FakePushNotifications(),
        serverConfigured: true,
      );

      await bootstrap.start();

      expect(bootstrap.status.value.hasToken, isTrue);
      expect(bootstrap.status.value.registered, isFalse);
      expect(bootstrap.status.value.error, contains('reach the push server'));

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('shows a notification for a foreground DM', () async {
      final FakeSocialService social = FakeSocialService();
      social.decryptPushKind = 14;
      social.decryptPushContent = 'see you there';
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushNotifications notifications = FakePushNotifications();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: FakePushRegistrationApi(),
          relays: const <String>[],
        ),
        social: social,
        notifications: notifications,
        serverConfigured: true,
      );

      await bootstrap.start();
      messaging.emitForeground('{"kind":1059}');
      await pumpEventQueue();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.body, 'see you there');

      await bootstrap.dispose();
      await messaging.dispose();
    });

    test('ignores a foreground live share (the map draws it)', () async {
      final FakeSocialService social = FakeSocialService();
      social.decryptPushKind = 20510;
      social.decryptPushContent = '{}';
      final FakePushMessaging messaging = FakePushMessaging(
        tokens: <PushTransport, String>{PushTransport.firebase: 'fcm-token-1'},
      );
      final FakePushNotifications notifications = FakePushNotifications();
      final PushRegistrationBootstrap bootstrap = PushRegistrationBootstrap(
        messaging: messaging,
        registrar: PushRegistrar(
          social: social,
          api: FakePushRegistrationApi(),
          relays: const <String>[],
        ),
        social: social,
        notifications: notifications,
        serverConfigured: true,
      );

      await bootstrap.start();
      messaging.emitForeground('{"kind":1059}');
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);

      await bootstrap.dispose();
      await messaging.dispose();
    });
  });
}
