import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/live_share.dart';
import 'package:openmaps/domain/usecases/publish_live_share.dart';

void main() {
  const String recipientA =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const String recipientB =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  final DateTime now = DateTime.now();

  LiveShareBroadcast broadcast({LatLon? position}) => LiveShareBroadcast(
    sessionId: 'session-1',
    kind: LiveShareBroadcastKind.update,
    position: position ?? const LatLon(52.52, 13.405),
    sampledAt: now,
    expiresAt: now.add(const Duration(hours: 1)),
  );

  test('publishes to normalized, de-duplicated recipients', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);
    final PublishLiveShare usecase = PublishLiveShare(service);

    await usecase(
      broadcast: broadcast(),
      recipientPubkeys: <String>[
        recipientA.toUpperCase(),
        ' $recipientB ',
        recipientA,
        'not-a-key',
        '',
      ],
    );

    expect(service.published, hasLength(1));
    expect(service.publishedRecipients.single, <String>[
      recipientA,
      recipientB,
    ]);
  });

  test('rejects an empty recipient set', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);
    final PublishLiveShare usecase = PublishLiveShare(service);

    await expectLater(
      usecase(broadcast: broadcast(), recipientPubkeys: const <String>['x']),
      throwsA(isA<ValidationException>()),
    );
    expect(service.published, isEmpty);
  });

  test('rejects an update with no position', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);
    final PublishLiveShare usecase = PublishLiveShare(service);
    final LiveShareBroadcast noPosition = LiveShareBroadcast(
      sessionId: 'session-1',
      kind: LiveShareBroadcastKind.update,
      position: null,
      sampledAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );

    await expectLater(
      usecase(broadcast: noPosition, recipientPubkeys: <String>[recipientA]),
      throwsA(isA<ValidationException>()),
    );
    expect(service.published, isEmpty);
  });

  test('rejects a broadcast with no session id', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);
    final PublishLiveShare usecase = PublishLiveShare(service);
    final LiveShareBroadcast anonymous = LiveShareBroadcast(
      sessionId: '  ',
      kind: LiveShareBroadcastKind.update,
      position: const LatLon(1, 2),
      sampledAt: now,
      expiresAt: now.add(const Duration(minutes: 5)),
    );

    await expectLater(
      usecase(broadcast: anonymous, recipientPubkeys: <String>[recipientA]),
      throwsA(isA<ValidationException>()),
    );
  });

  test('a stop broadcast may omit the position', () async {
    final FakeSocialService service = FakeSocialService();
    addTearDown(service.dispose);
    final PublishLiveShare usecase = PublishLiveShare(service);
    final LiveShareBroadcast stop = LiveShareBroadcast(
      sessionId: 'session-1',
      kind: LiveShareBroadcastKind.stop,
      position: null,
      sampledAt: now,
      expiresAt: now,
    );

    await usecase(broadcast: stop, recipientPubkeys: <String>[recipientA]);
    expect(service.published.single.kind, LiveShareBroadcastKind.stop);
  });
}
