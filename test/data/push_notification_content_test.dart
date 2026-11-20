import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/nostr/live_location_payload.dart';
import 'package:openmaps/data/notifications/push_notification_content.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/live_share.dart';

const String _sender =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

LiveShareBroadcast _share({
  LiveShareBroadcastKind kind = LiveShareBroadcastKind.start,
}) {
  final DateTime now = DateTime.now();
  return LiveShareBroadcast(
    sessionId: 'session-1',
    kind: kind,
    position: const LatLon(52.52, 13.405),
    sampledAt: now,
    expiresAt: now.add(const Duration(minutes: 30)),
  );
}

void main() {
  group('PushNotificationContent', () {
    test('maps a live-share start to a notification', () {
      final PushNotificationContent? content =
          PushNotificationContent.fromDecryptedEvent(
            kind: LiveLocationPayload.rumorKind,
            content: LiveLocationPayload.encode(_share()),
            senderPubkey: _sender,
            senderName: 'Mira',
          );

      expect(content, isNotNull);
      expect(content!.title, 'Mira');
      expect(content.body, contains('sharing their location'));
      expect(content.payload, contains('/friends'));
    });

    test('ignores a live-share position update (only a start notifies)', () {
      final PushNotificationContent? content =
          PushNotificationContent.fromDecryptedEvent(
            kind: LiveLocationPayload.rumorKind,
            content: LiveLocationPayload.encode(
              _share(kind: LiveShareBroadcastKind.update),
            ),
            senderPubkey: _sender,
          );

      expect(content, isNull);
    });

    test('ignores a share stop', () {
      final PushNotificationContent? content =
          PushNotificationContent.fromDecryptedEvent(
            kind: LiveLocationPayload.rumorKind,
            content: LiveLocationPayload.encode(
              _share(kind: LiveShareBroadcastKind.stop),
            ),
            senderPubkey: _sender,
          );

      expect(content, isNull);
    });

    test('maps a direct message', () {
      final PushNotificationContent? content =
          PushNotificationContent.fromDecryptedEvent(
            kind: PushNotificationContent.directMessageKind,
            content: '  see you at the cafe  ',
            senderPubkey: _sender,
          );

      expect(content, isNotNull);
      expect(content!.body, 'see you at the cafe');
      expect(content.payload, contains('/messages/$_sender'));
    });

    test('ignores kinds the app does not surface', () {
      expect(
        PushNotificationContent.fromDecryptedEvent(
          kind: 1,
          content: 'a public note',
          senderPubkey: _sender,
        ),
        isNull,
      );
    });

    test('falls back to a short key when the sender is unnamed', () {
      final PushNotificationContent? content =
          PushNotificationContent.fromDecryptedEvent(
            kind: LiveLocationPayload.rumorKind,
            content: LiveLocationPayload.encode(_share()),
            senderPubkey: _sender,
          );

      expect(content, isNotNull);
      expect(content!.title, contains('…'));
    });

    test('a malformed live-share payload is ignored', () {
      expect(
        PushNotificationContent.fromDecryptedEvent(
          kind: LiveLocationPayload.rumorKind,
          content: 'not json',
          senderPubkey: _sender,
        ),
        isNull,
      );
    });
  });
}
