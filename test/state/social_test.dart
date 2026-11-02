import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_live_share_notifications.dart';
import 'package:openmaps/data/fakes/fake_live_share_store.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/domain/entities/friend_location.dart';
import 'package:openmaps/domain/entities/friend_marker.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/live_share.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

/// A controllable [LocationService] for the live-share controller tests.
class _TestLocationService implements LocationService {
  _TestLocationService({this.sample});

  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();

  LocationSample? sample;

  @override
  Future<LocationSample?> lastKnown() async => sample;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  void emit(LocationSample next) {
    sample = next;
    _controller.add(next);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  late FakeSocialService social;
  late FakeLiveShareStore store;
  late FakeLiveShareNotifications notifications;
  late ProviderContainer container;

  const LocationSample berlin = LocationSample(
    position: LatLon(52.52, 13.405),
    accuracyMeters: 8,
  );

  Future<ProviderContainer> build({
    LocationSample? sample = berlin,
    _TestLocationService? location,
  }) async {
    container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(social),
        liveShareStoreProvider.overrideWithValue(store),
        liveShareNotificationsProvider.overrideWithValue(notifications),
        locationServiceProvider.overrideWithValue(
          location ?? _TestLocationService(sample: sample),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    social = FakeSocialService();
    store = FakeLiveShareStore();
    notifications = FakeLiveShareNotifications();
  });

  test('starting a share publishes, notifies and persists', () async {
    final ProviderContainer c = await build();
    final List<Friend> friends = await c.read(friendsProvider.future);
    expect(friends, isNotEmpty);

    await c
        .read(liveShareProvider.notifier)
        .start(
          recipients: <String>[friends.first.pubkey],
          duration: const Duration(minutes: 30),
        );

    final LiveShareState state = c.read(liveShareProvider);
    expect(state.isActive, isTrue);
    expect(state.recipientCount, 1);
    expect(state.expiresAt, isNotNull);

    expect(social.published, hasLength(1));
    expect(social.published.single.kind, LiveShareBroadcastKind.update);
    expect(social.published.single.position, berlin.position);
    expect(social.publishedRecipients.single, <String>[friends.first.pubkey]);

    expect(notifications.visible, isTrue);
    expect(notifications.title, 'Sharing your live location');
    expect(notifications.body, contains('1 friend'));

    expect(store.session, isNotNull);
    expect(store.session!.recipients, <String>[friends.first.pubkey]);

    await c.read(liveShareProvider.notifier).stop();
  });

  test('stopping publishes a stop, dismisses and clears', () async {
    final ProviderContainer c = await build();
    final List<Friend> friends = await c.read(friendsProvider.future);
    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>[friends.first.pubkey]);

    await c.read(liveShareProvider.notifier).stop();

    expect(c.read(liveShareProvider).status, LiveShareStatus.idle);
    expect(social.published.last.kind, LiveShareBroadcastKind.stop);
    expect(social.publishedRecipients.last, <String>[friends.first.pubkey]);
    expect(notifications.visible, isFalse);
    expect(store.session, isNull);
  });

  test('starting without a location fix fails with a clear message', () async {
    final ProviderContainer c = await build(sample: null);

    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>['a' * 64]);

    final LiveShareState state = c.read(liveShareProvider);
    expect(state.status, LiveShareStatus.error);
    expect(state.error, contains('location'));
    expect(social.published, isEmpty);
    expect(notifications.visible, isFalse);
    expect(store.session, isNull);
  });

  test('a relay failure on start surfaces an error and cleans up', () async {
    social.publishError = const NetworkException('relays unreachable');
    final ProviderContainer c = await build();

    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>['a' * 64]);

    final LiveShareState state = c.read(liveShareProvider);
    expect(state.status, LiveShareStatus.error);
    expect(state.error, 'relays unreachable');
    expect(store.session, isNull);
    expect(notifications.visible, isFalse);
  });

  test('a later publish failure keeps sharing and records the error', () async {
    final _TestLocationService location = _TestLocationService(sample: berlin);
    addTearDown(location.dispose);
    final ProviderContainer c = await build(location: location);
    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>['a' * 64]);

    social.publishError = const NetworkException('flaky relay');
    location.emit(
      const LocationSample(position: LatLon(52.53, 13.42), accuracyMeters: 5),
    );
    await pumpEventQueue();

    final LiveShareState state = c.read(liveShareProvider);
    expect(state.isActive, isTrue);
    expect(state.error, 'flaky relay');

    await c.read(liveShareProvider.notifier).stop();
  });

  test('starting twice while active is a no-op', () async {
    final ProviderContainer c = await build();
    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>['a' * 64]);
    await c
        .read(liveShareProvider.notifier)
        .start(recipients: <String>['b' * 64]);

    expect(social.published, hasLength(1));
    expect(c.read(liveShareProvider).recipients, <String>['a' * 64]);

    await c.read(liveShareProvider.notifier).stop();
  });

  test('an expired stored session is discarded on restore', () async {
    final DateTime now = DateTime.now();
    store.session = LiveShareSession(
      sessionId: 'old',
      recipients: <String>['a' * 64],
      startedAt: now.subtract(const Duration(hours: 2)),
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    final ProviderContainer c = await build();
    // Reading the notifier builds it (and kicks off the restore).
    expect(c.read(liveShareProvider).status, LiveShareStatus.idle);
    await pumpEventQueue();

    expect(c.read(liveShareProvider).status, LiveShareStatus.idle);
    expect(store.session, isNull);
    expect(notifications.visible, isFalse);
  });

  test('a live stored session is restored with its notification', () async {
    final DateTime now = DateTime.now();
    store.session = LiveShareSession(
      sessionId: 'resumed',
      recipients: <String>['a' * 64],
      startedAt: now,
      expiresAt: now.add(const Duration(minutes: 20)),
    );
    final _TestLocationService location = _TestLocationService(sample: berlin);
    addTearDown(location.dispose);
    final ProviderContainer c = await build(location: location);
    // Building the provider kicks off the restore; let it settle.
    expect(c.read(liveShareProvider).status, LiveShareStatus.idle);
    await pumpEventQueue();

    final LiveShareState state = c.read(liveShareProvider);
    expect(state.isActive, isTrue);
    expect(state.expiresAt, isNotNull);
    expect(notifications.visible, isTrue);

    await c.read(liveShareProvider.notifier).stop();
  });

  test(
    'friend locations land in state and on the map, then end cleanly',
    () async {
      final ProviderContainer c = await build();
      // Keep both providers alive while the fake emits.
      final ProviderSubscription<List<FriendLocation>> sub = c.listen(
        friendLocationsProvider,
        (List<FriendLocation>? _, List<FriendLocation> _) {},
      );
      final ProviderSubscription<List<FriendMarker>> markerSub = c.listen(
        friendMarkersProvider,
        (List<FriendMarker>? _, List<FriendMarker> _) {},
      );
      addTearDown(sub.close);
      addTearDown(markerSub.close);
      await pumpEventQueue();

      final DateTime now = DateTime.now();
      final Friend friend = FakeSocialService.demoFriends.first;
      social.emit(
        FriendLocation(
          pubkey: friend.pubkey,
          position: const LatLon(52.521, 13.409),
          updatedAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
          displayName: friend.displayName,
        ),
      );
      await pumpEventQueue();

      expect(c.read(friendLocationsProvider), hasLength(1));
      final FakeMapService map = c.read(mapServiceProvider) as FakeMapService;
      expect(map.friendMarkers, hasLength(1));
      expect(map.friendMarkers.single.pubkey, friend.pubkey);
      expect(map.friendMarkers.single.label, 'Mira');

      social.emit(
        FriendLocation(
          pubkey: friend.pubkey,
          updatedAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
          ended: true,
        ),
      );
      await pumpEventQueue();

      expect(c.read(friendLocationsProvider), isEmpty);
      expect(map.friendMarkers, isEmpty);
    },
  );

  test(
    'an unknown sender has their profile resolved onto the location',
    () async {
      final ProviderContainer c = await build();
      final ProviderSubscription<List<FriendLocation>> sub = c.listen(
        friendLocationsProvider,
        (List<FriendLocation>? _, List<FriendLocation> _) {},
      );
      addTearDown(sub.close);
      await pumpEventQueue();

      final DateTime now = DateTime.now();
      const String stranger =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      social.emit(
        FriendLocation(
          pubkey: stranger,
          position: const LatLon(52.52, 13.4),
          updatedAt: now,
          expiresAt: now.add(const Duration(minutes: 30)),
        ),
      );
      await pumpEventQueue();

      final FriendLocation location = c.read(friendLocationsProvider).single;
      expect(location.pubkey, stranger);
      // The fake resolves a name for any key, so the pin is labelled.
      expect(location.displayName, isNotNull);
      expect(location.label, isNot(contains('…')));
    },
  );

  test('a stale friend location is filtered out on read', () async {
    final ProviderContainer c = await build();
    final ProviderSubscription<List<FriendLocation>> sub = c.listen(
      friendLocationsProvider,
      (List<FriendLocation>? _, List<FriendLocation> _) {},
    );
    addTearDown(sub.close);
    await pumpEventQueue();

    final DateTime now = DateTime.now();
    final Friend friend = FakeSocialService.demoFriends.first;
    social.emit(
      FriendLocation(
        pubkey: friend.pubkey,
        position: const LatLon(52.521, 13.409),
        // Sampled long ago: it is live only if both fresh and unexpired.
        updatedAt: now.subtract(const Duration(minutes: 30)),
        expiresAt: now.add(const Duration(minutes: 30)),
      ),
    );
    await pumpEventQueue();

    expect(c.read(friendLocationsProvider), isEmpty);
  });
}
