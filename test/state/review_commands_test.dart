import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/review_place.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';
import 'package:openmaps/state/social.dart';

/// Every review action is a command id (AGENTS.md §Driving the app), so this
/// suite drives the feature the way an agent or the UI would.
void main() {
  late FakeReviewService reviews;
  late FakeOsmPlaceSource osm;
  late ProviderContainer container;

  setUp(() {
    reviews = FakeReviewService();
    osm = FakeOsmPlaceSource();
    container = ProviderContainer(
      overrides: <Override>[
        reviewServiceProvider.overrideWithValue(reviews),
        socialServiceProvider.overrideWithValue(FakeSocialService()),
        osmPlaceSourceProvider.overrideWithValue(osm),
        mapServiceProvider.overrideWith((Ref ref) {
          final FakeMapService map = FakeMapService();
          ref.onDispose(map.dispose);
          return map;
        }),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<Object?> dispatch(
    String id, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) => container.read(commandRegistryProvider).dispatch(id, params);

  test('review.compose opens a draft for the selected place', () async {
    await dispatch('place.select', <String, Object?>{
      'id': 'sample-harbour-coffee',
      'focus': false,
    });
    final Map<String, Object?> draft =
        await dispatch('review.compose') as Map<String, Object?>;
    expect(draft['open'], isTrue);
    expect(draft['placeKey'], ReviewPlace.keyFor('sample-harbour-coffee'));
  });

  test('review.draft.set updates rating, text and visibility', () async {
    await dispatch('review.compose', <String, Object?>{
      'id': 'sample-harbour-coffee',
    });
    final Map<String, Object?> draft = await dispatch(
      'review.draft.set',
      <String, Object?>{'stars': 4, 'text': 'Great coffee'},
    ) as Map<String, Object?>;
    expect(draft['stars'], 4);
    expect(draft['rating'], closeTo(0.8, 1e-9));
    expect(draft['text'], 'Great coffee');
    expect(draft['visibility'], 'public');
    expect(draft['canPublish'], isTrue);

    final Map<String, Object?> friends = await dispatch(
      'review.draft.set',
      <String, Object?>{'visibility': 'friends'},
    ) as Map<String, Object?>;
    expect(friends['visibility'], 'friends');
  });

  test('review.photo.add attaches bytes to the draft', () async {
    await dispatch('review.compose', <String, Object?>{
      'id': 'sample-harbour-coffee',
    });
    final Map<String, Object?> draft = await dispatch(
      'review.photo.add',
      <String, Object?>{'base64': 'AQIDBA==', 'mimeType': 'image/jpeg'},
    ) as Map<String, Object?>;
    expect(draft['localPhotos'], 1);
  });

  test('review.publish then review.list shows the new review', () async {
    await dispatch('review.compose', <String, Object?>{
      'id': 'sample-harbour-coffee',
    });
    await dispatch('review.draft.set', <String, Object?>{
      'stars': 5,
      'text': 'Excellent evening',
    });
    final Map<String, Object?> published =
        await dispatch('review.publish') as Map<String, Object?>;
    expect(published['status'], 'published');
    expect(reviews.published, hasLength(1));

    final Map<String, Object?> summary = await dispatch(
      'review.list',
      <String, Object?>{'id': 'sample-harbour-coffee'},
    ) as Map<String, Object?>;
    expect(summary['placeKey'], ReviewPlace.keyFor('sample-harbour-coffee'));
    final List<Object?> list = summary['reviews']! as List<Object?>;
    expect(
      list.any(
        (Object? entry) =>
            (entry! as Map<String, Object?>)['text'] == 'Excellent evening',
      ),
      isTrue,
    );
  });

  test('review.publish reports a failure as a command error', () async {
    await dispatch('review.compose', <String, Object?>{
      'id': 'sample-harbour-coffee',
    });
    await dispatch('review.draft.set', <String, Object?>{
      'stars': 5,
      'visibility': 'friends',
    });
    await expectLater(
      dispatch('review.publish'),
      throwsA(isA<CommandException>()),
    );
    expect(container.read(reviewComposerProvider).status.name, 'error');
  });

  test('review.simulate.add injects a review for the demo backend', () async {
    final Map<String, Object?> seeded = await dispatch(
      'review.simulate.add',
      <String, Object?>{
        'id': 'sample-city-library',
        'friend': true,
        'rating': 1.0,
        'text': 'Quiet and bright',
      },
    ) as Map<String, Object?>;
    expect(seeded['rating'], 1.0);
    expect(seeded['text'], 'Quiet and bright');
    final Object? summary = await dispatch('review.list', <String, Object?>{
      'id': 'sample-city-library',
    });
    final List<Object?> list =
        (summary! as Map<String, Object?>)['reviews']! as List<Object?>;
    expect(list, hasLength(1));
  });

  test('map.reviews.friendOnly toggles the mode', () async {
    expect(await dispatch('map.reviews.friendOnly'), isTrue);
    expect(container.read(friendReviewsOnlyProvider), isTrue);
    expect(
      await dispatch('map.reviews.friendOnly', <String, Object?>{'on': false}),
      isFalse,
    );
  });

  test('review.helpful toggles and sets the helpful flag', () async {
    expect(
      await dispatch('review.helpful', <String, Object?>{
        'id': 'demo-review-1',
      }),
      isTrue,
    );
    expect(container.read(helpfulReviewsProvider), contains('demo-review-1'));
    expect(
      await dispatch('review.helpful', <String, Object?>{
        'id': 'demo-review-1',
      }),
      isFalse,
    );
    expect(container.read(helpfulReviewsProvider), isEmpty);
    expect(
      await dispatch('review.helpful', <String, Object?>{
        'id': 'demo-review-1',
        'helpful': true,
      }),
      isTrue,
    );
    await expectLater(
      dispatch('review.helpful', <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });

  test('review.copy returns and copies the review text', () async {
    expect(
      await dispatch('review.copy', <String, Object?>{
        'text': 'Beautiful acoustics.',
      }),
      'Beautiful acoustics.',
    );
    await expectLater(
      dispatch('review.copy', <String, Object?>{'text': '   '}),
      throwsA(isA<CommandException>()),
    );
  });

  test('review.open selects a place for a review badge', () async {
    final Map<String, Object?> place = await dispatch(
      'review.open',
      <String, Object?>{
        'placeKey': ReviewPlace.keyFor('sample-harbour-coffee'),
        'focus': false,
      },
    ) as Map<String, Object?>;
    expect(place['name'], 'Harbour Coffee');
  });

  test('review.open synthesises a place when it is not in our data', () async {
    final Map<String, Object?> place = await dispatch(
      'review.open',
      <String, Object?>{'id': 'unknown-place', 'focus': false},
    ) as Map<String, Object?>;
    expect(place['id'], 'unknown-place');
    // Nothing to look up: a readable label, not the raw id.
    expect(place['name'], 'Unknown Place');
  });

  test(
    'review.open looks an OSM element up so the sheet has a real name',
    () async {
      osm.seed(
        'way/123456',
        const Place(
          id: 'way/123456',
          name: 'BlueBox Sonnenstudio',
          position: LatLon(52.5194096, 13.4119486),
          category: 'beauty',
          address: 'Grunerstraße 7, Berlin',
        ),
      );
      final Map<String, Object?> place = await dispatch(
        'review.open',
        <String, Object?>{
          'placeKey': 'openstreetmap:way/123456',
          'focus': false,
        },
      ) as Map<String, Object?>;
      expect(place['name'], 'BlueBox Sonnenstudio');
      expect(place['address'], contains('Grunerstraße'));
      expect(place['lat'], closeTo(52.5194096, 1e-6));
      expect(osm.lookups, <String>['way/123456']);
      // The sheet is keyed by the OSM reference, so its reviews match.
      expect(container.read(selectedPlaceProvider)?.id, 'way/123456');
    },
  );

  test(
    'review.open keeps a readable fallback when the lookup finds nothing',
    () async {
      final Map<String, Object?> place = await dispatch(
        'review.open',
        <String, Object?>{
          'placeKey': 'openstreetmap:node/2764050762',
          'focus': false,
        },
      ) as Map<String, Object?>;
      expect(place['name'], 'Node 2764050762');
      expect(osm.lookups, <String>['node/2764050762']);
    },
  );

  test('review.compose.close closes the sheet', () async {
    await dispatch('review.compose', <String, Object?>{
      'id': 'sample-harbour-coffee',
    });
    await dispatch('review.compose.close');
    expect(container.read(reviewComposerProvider).isOpen, isFalse);
  });

  test('review commands reject hostile parameters', () async {
    await expectLater(
      dispatch('review.list'),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      dispatch('review.photo.add', <String, Object?>{'base64': 'not base64'}),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      dispatch('review.open'),
      throwsA(isA<CommandException>()),
    );
  });

  test('seeded reviews carry the friend flag through review.list', () async {
    await container.read(friendsProvider.future);
    final Map<String, Object?> summary = await dispatch(
      'review.list',
      <String, Object?>{'id': 'sample-harbour-coffee'},
    ) as Map<String, Object?>;
    expect(summary['friends'], 2);
    final List<Object?> list = summary['reviews']! as List<Object?>;
    expect(
      list.where((Object? e) => (e! as Map<String, Object?>)['friend'] == true),
      hasLength(2),
    );
  });
}
