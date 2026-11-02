import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_live_share_notifications.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/friend.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

void main() {
  late FakeSocialService social;
  late ProviderContainer container;

  setUp(() {
    social = FakeSocialService();
    container = ProviderContainer(
      overrides: <Override>[
        socialServiceProvider.overrideWithValue(social),
        liveShareNotificationsProvider.overrideWithValue(
          FakeLiveShareNotifications(),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<Object?> dispatch(
    String id, [
    Map<String, Object?> params = const {},
  ]) => container.read(commandRegistryProvider).dispatch(id, params);

  test('social.state reports the identity and an idle share', () async {
    final Map<String, Object?> state =
        await dispatch('social.state') as Map<String, Object?>;
    expect(state['signedIn'], isTrue);
    expect(state['pubkey'], FakeSocialService.demoUserPubkey);
    expect(state['friendsLive'], isEmpty);
    expect((state['share']! as Map<String, Object?>)['status'], 'idle');
  });

  test('social.friends lists the demo friends', () async {
    final List<Object?> friends =
        await dispatch('social.friends') as List<Object?>;
    expect(friends, hasLength(4));
    final Map<String, Object?> first = friends.first as Map<String, Object?>;
    expect(first['name'], isA<String>());
    expect(first['live'], isFalse);
  });

  test(
    'social.simulate.friendLocation then social.friends shows live',
    () async {
      final Map<String, Object?> seeded = await dispatch(
        'social.simulate.friendLocation',
      ) as Map<String, Object?>;
      expect(seeded['pubkey'], isA<String>());
      expect(seeded['lat'], isA<double>());
      await pumpEventQueue();

      final List<Object?> live =
          await dispatch('social.friendLocations') as List<Object?>;
      expect(live, hasLength(1));

      final List<Object?> friends =
          await dispatch('social.friends') as List<Object?>;
      final int liveCount = friends.where((Object? f) {
        return (f! as Map<String, Object?>)['live'] == true;
      }).length;
      expect(liveCount, 1);

      final Map<String, Object?> state =
          await dispatch('social.state') as Map<String, Object?>;
      expect(state['friendsLive'], hasLength(1));
    },
  );

  test('social.friend.select opens and clears the friend sheet', () async {
    final Friend friend = FakeSocialService.demoFriends.first;
    expect(
      await dispatch('social.friend.select', <String, Object?>{
        'pubkey': friend.pubkey,
      }),
      friend.pubkey,
    );
    expect(container.read(selectedFriendProvider), friend.pubkey);

    await dispatch('social.friend.select');
    expect(container.read(selectedFriendProvider), isNull);
  });

  test('map.friendMarkers reflects the live friends on the map', () async {
    await dispatch('social.simulate.friendLocation');
    await pumpEventQueue();

    final List<Object?> markers =
        await dispatch('map.friendMarkers') as List<Object?>;
    expect(markers, hasLength(1));
    final Map<String, Object?> first = markers.first as Map<String, Object?>;
    expect(first['label'], 'Mira');
    expect(first['lat'], isA<double>());
    expect(first['lon'], isA<double>());
  });

  test(
    'social.friend.add and social.friend.remove manage the friends set',
    () async {
      const String key =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

      expect(
        await dispatch('social.friend.add', <String, Object?>{'pubkey': key}),
        isTrue,
      );

      final List<Object?> friends =
          await dispatch('social.friends') as List<Object?>;
      expect(
        friends.any(
          (Object? f) => (f! as Map<String, Object?>)['pubkey'] == key,
        ),
        isTrue,
      );

      await dispatch('social.friend.remove', <String, Object?>{'pubkey': key});
      final List<Object?> after =
          await dispatch('social.friends') as List<Object?>;
      expect(
        after.any((Object? f) => (f! as Map<String, Object?>)['pubkey'] == key),
        isFalse,
      );

      await expectLater(
        dispatch('social.friend.add', <String, Object?>{'pubkey': 'nope'}),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        dispatch('social.friend.add'),
        throwsA(isA<CommandException>()),
      );
    },
  );

  test('social.followings lists who you follow, flagged once added', () async {
    List<Object?> followings =
        await dispatch('social.followings') as List<Object?>;
    expect(followings, hasLength(2));
    expect(
      followings.every(
        (Object? f) => (f! as Map<String, Object?>)['friend'] == false,
      ),
      isTrue,
    );

    final String first =
        (followings.first! as Map<String, Object?>)['pubkey']! as String;
    await dispatch('social.friend.add', <String, Object?>{'pubkey': first});

    followings = await dispatch('social.followings') as List<Object?>;
    final int flagged = followings
        .where((Object? f) => (f! as Map<String, Object?>)['friend'] == true)
        .length;
    expect(flagged, 1);

    // Adding one friend did not copy the rest of the follow list in.
    final List<Object?> friends =
        await dispatch('social.friends') as List<Object?>;
    expect(friends, hasLength(5));
  });

  test('social.share.start all → active → stop', () async {
    final Map<String, Object?> started = await dispatch(
      'social.share.start',
      <String, Object?>{'recipients': 'all', 'durationMinutes': 30},
    ) as Map<String, Object?>;

    expect(started['status'], 'active');
    expect(started['recipientCount'], 4);
    expect(social.published, hasLength(1));

    final Map<String, Object?> state =
        await dispatch('social.share.state') as Map<String, Object?>;
    expect(state['status'], 'active');

    final Map<String, Object?> stopped =
        await dispatch('social.share.stop') as Map<String, Object?>;
    expect(stopped['status'], 'idle');
  });

  test('social.friend.select focuses the camera, or only opens on request', () async {
    await dispatch('social.simulate.friendLocation', <String, Object?>{
      'lat': 52.6,
      'lon': 13.5,
    });
    await pumpEventQueue();
    final String pubkey =
        (container.read(friendLocationsProvider).single).pubkey;
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;

    await dispatch('social.friend.select', <String, Object?>{'pubkey': pubkey});
    expect(container.read(selectedFriendProvider), pubkey);
    expect(map.camera.target.latitude, closeTo(52.6, 0.05));
    expect(map.camera.zoom, 16);

    // focus:false leaves the camera where it is (a pin tap already on screen).
    await dispatch('map.camera.set', <String, Object?>{
      'lat': 1,
      'lon': 2,
      'zoom': 10,
    });
    await dispatch('social.friend.select', <String, Object?>{
      'pubkey': pubkey,
      'focus': false,
    });
    expect(map.camera.target.latitude, 1);
    expect(map.camera.zoom, 10);
  });

  test('map.fitFriends frames every live friend', () async {
    await expectLater(
      dispatch('map.fitFriends'),
      throwsA(isA<CommandException>()),
    );

    await dispatch('social.simulate.friendLocation', <String, Object?>{
      'lat': 52.5,
      'lon': 13.4,
    });
    await dispatch('social.simulate.friendLocation', <String, Object?>{
      'pubkey':
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      'lat': 52.6,
      'lon': 13.5,
    });
    await pumpEventQueue();
    expect(container.read(friendLocationsProvider), hasLength(2));

    expect(await dispatch('map.fitFriends'), 2);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    // Fitted between the two friends.
    expect(map.camera.target.latitude, closeTo(52.55, 0.05));
    expect(map.camera.target.longitude, closeTo(13.45, 0.05));
  });

  test('map.fitFriends centres a single live friend', () async {
    await dispatch('social.simulate.friendLocation', <String, Object?>{
      'lat': 52.5,
      'lon': 13.4,
    });
    await pumpEventQueue();

    expect(await dispatch('map.fitFriends'), 1);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.camera.target.latitude, closeTo(52.5, 0.05));
    expect(map.camera.zoom, 16);
  });

  test('social.share.start accepts "self" as a private preview', () async {
    final Map<String, Object?> started = await dispatch(
      'social.share.start',
      <String, Object?>{'recipients': 'self', 'durationMinutes': 5},
    ) as Map<String, Object?>;

    expect(started['status'], 'active');
    expect(started['recipients'], <String>[FakeSocialService.demoUserPubkey]);
    await dispatch('social.share.stop');
  });

  test('social.share.start validates its params', () async {
    await expectLater(
      dispatch('social.share.start'),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      dispatch('social.share.start', <String, Object?>{
        'recipients': <Object?>['nope'],
      }),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      dispatch('social.share.start', <String, Object?>{
        'recipients': 'all',
        'durationMinutes': 99999,
      }),
      throwsA(isA<CommandException>()),
    );
  });

  test('social.login requires a key and social.logout signs out', () async {
    await expectLater(
      dispatch('social.login'),
      throwsA(isA<CommandException>()),
    );

    await dispatch('social.login', <String, Object?>{'nsec': 'nsec1demo'});
    expect(social.signedInWithKey, 'nsec1demo');

    await dispatch('social.logout');
    expect(await dispatch('social.friends'), isEmpty);
    expect(
      ((await dispatch('social.state'))! as Map<String, Object?>)['signedIn'],
      isFalse,
    );
  });
}
