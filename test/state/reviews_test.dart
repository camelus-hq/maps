import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/review.dart';
import 'package:openmaps/domain/entities/review_draft.dart';
import 'package:openmaps/domain/entities/review_marker.dart';
import 'package:openmaps/domain/entities/review_place.dart';
import 'package:openmaps/domain/entities/review_summary.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/reviews.dart';
import 'package:openmaps/state/social.dart';

void main() {
  late FakeReviewService reviews;
  late ProviderContainer container;
  final String coffee = ReviewPlace.keyFor('sample-harbour-coffee');

  const Place harbourCoffee = Place(
    id: 'sample-harbour-coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5210, 13.4075),
    category: 'Cafe',
  );

  setUp(() {
    reviews = FakeReviewService();
    container = ProviderContainer(
      overrides: <Override>[
        reviewServiceProvider.overrideWithValue(reviews),
        socialServiceProvider.overrideWithValue(FakeSocialService()),
      ],
    );
  });

  tearDown(() => container.dispose());

  group('place reviews', () {
    test('are enriched with friend flags and author names', () async {
      await container.read(friendsProvider.future);
      final List<Review> reviews = await container.read(
        placeReviewsProvider(coffee).future,
      );
      expect(reviews, hasLength(3));
      final ReviewSummary summary = container.read(
        placeReviewSummaryProvider(coffee),
      );
      expect(summary.reviewCount, 3);
      expect(summary.friendCount, 2);
      expect(summary.stars, closeTo(4.5, 0.2));
      final Review headline = summary.headline!;
      expect(headline.isFriend, isTrue);
      expect(headline.authorName, isNotNull);
    });

    test('are empty (never an error) for an invalid place key', () async {
      final List<Review> reviews = await container.read(
        placeReviewsProvider('not-a-place').future,
      );
      expect(reviews, isEmpty);
      expect(
        container.read(placeReviewSummaryProvider('not-a-place')).isEmpty,
        isTrue,
      );
    });
  });

  group('composer', () {
    test('tracks the draft and publishes a public review', () async {
      final ReviewComposerController composer = container.read(
        reviewComposerProvider.notifier,
      );
      composer.open(harbourCoffee);
      expect(container.read(reviewComposerProvider).isOpen, isTrue);
      expect(container.read(reviewComposerProvider).draft!.placeKey, coffee);

      composer.setStars(4);
      composer.setText('Great flat white');
      expect(container.read(reviewComposerProvider).stars, 4);
      expect(container.read(reviewComposerProvider).draft!.canPublish, isTrue);

      await composer.publish();
      expect(
        container.read(reviewComposerProvider).status,
        ReviewComposerStatus.published,
      );
      expect(reviews.published, hasLength(1));
      expect(reviews.published.single.rating, 0.8);
    });

    test('refuses to publish a friends-only review', () async {
      final ReviewComposerController composer = container.read(
        reviewComposerProvider.notifier,
      );
      composer.open(harbourCoffee);
      composer.setStars(5);
      composer.setVisibility(ReviewVisibility.friends);
      await composer.publish();
      final ReviewComposerState state = container.read(reviewComposerProvider);
      expect(state.status, ReviewComposerStatus.error);
      expect(state.error, contains('not available yet'));
      expect(reviews.published, isEmpty);
    });

    test('bounds the text and caps the photos', () async {
      final ReviewComposerController composer = container.read(
        reviewComposerProvider.notifier,
      );
      composer.open(harbourCoffee);
      composer.setText('x' * (ReviewDraft.maxTextLength + 500));
      expect(
        container.read(reviewComposerProvider).draft!.text.length,
        ReviewDraft.maxTextLength,
      );
      composer.addPhotos(<ReviewPhoto>[
        for (int i = 0; i < 9; i++)
          ReviewPhoto(data: Uint8List.fromList(<int>[i])),
      ]);
      expect(
        container.read(reviewComposerProvider).draft!.photos.length,
        ReviewDraft.maxPhotos,
      );
    });

    test('surfaces a publish failure as an error state', () async {
      reviews.publishError = const NetworkException('relays unreachable');
      final ReviewComposerController composer = container.read(
        reviewComposerProvider.notifier,
      );
      composer.open(harbourCoffee);
      composer.setStars(5);
      await composer.publish();
      final ReviewComposerState state = container.read(reviewComposerProvider);
      expect(state.status, ReviewComposerStatus.error);
      expect(state.error, 'relays unreachable');
    });
  });

  group('map badges', () {
    test('are one per place, with the friend count highlighted', () async {
      await container.read(friendsProvider.future);
      container
          .read(reviewMarkersProvider.notifier)
          .update(
            const Camera(target: LatLon(52.52, 13.405), zoom: 16),
            const Size(400, 800),
          );
      await pumpEventQueue();
      final List<ReviewMarker> markers = container.read(reviewMarkersProvider);
      expect(markers, isNotEmpty);
      final ReviewMarker coffeeMarker = markers.firstWhere(
        (ReviewMarker m) => m.placeKey == coffee,
      );
      expect(coffeeMarker.reviewCount, 3);
      expect(coffeeMarker.friendCount, 2);
      expect(coffeeMarker.hasFriendReview, isTrue);
      expect(coffeeMarker.badgeLabel, contains('friends'));
    });

    test('friendOnly keeps only friend-reviewed places', () async {
      await container.read(friendsProvider.future);
      final ReviewMarkersController controller = container.read(
        reviewMarkersProvider.notifier,
      );
      controller.update(
        const Camera(target: LatLon(52.52, 13.405), zoom: 16),
        const Size(400, 800),
      );
      await pumpEventQueue();
      final int all = container.read(reviewMarkersProvider).length;
      controller.setFriendOnly(true);
      final List<ReviewMarker> friends = container.read(reviewMarkersProvider);
      expect(friends.length, lessThanOrEqualTo(all));
      expect(friends.every((ReviewMarker m) => m.hasFriendReview), isTrue);
    });

    test('a query outside populated bounds yields no badges', () async {
      container
          .read(reviewMarkersProvider.notifier)
          .update(
            const Camera(target: LatLon(0, 0), zoom: 16),
            const Size(400, 800),
          );
      await pumpEventQueue();
      expect(container.read(reviewMarkersProvider), isEmpty);
    });

    test('nothing is drawn (or queried) when the map is zoomed out', () async {
      await container.read(friendsProvider.future);
      final ReviewMarkersController controller = container.read(
        reviewMarkersProvider.notifier,
      );
      controller.update(
        const Camera(target: LatLon(52.52, 13.405), zoom: 16),
        const Size(400, 800),
      );
      await pumpEventQueue();
      expect(container.read(reviewMarkersProvider), isNotEmpty);

      controller.update(
        const Camera(target: LatLon(52.52, 13.405), zoom: 11),
        const Size(400, 800),
      );
      await pumpEventQueue();
      expect(container.read(reviewMarkersProvider), isEmpty);
      expect(container.read(mapServiceProvider).reviewMarkers, isEmpty);
    });

    test('overlapping badges keep the friend-reviewed place', () async {
      // Two places a few metres apart: only one badge can be read.
      const LatLon spot = LatLon(52.5195, 13.4120);
      final FakeReviewService service = FakeReviewService(
        reviews: const <Review>[],
      );
      service.seed(
        Review(
          id: 'stranger',
          authorPubkey: '9000000000000000000000000000000000000000000000000000000000000001',
          placeKey: ReviewPlace.keyFor('sample-city-library'),
          rating: 0.8,
          content: 'Good',
          position: spot,
          createdAt: DateTime.utc(2026),
        ),
      );
      service.seed(
        Review(
          id: 'friend',
          authorPubkey: FakeSocialService.demoFriends.first.pubkey,
          placeKey: ReviewPlace.keyFor('sample-willow-park'),
          rating: 0.8,
          content: 'Great',
          position: spot,
          createdAt: DateTime.utc(2026),
        ),
      );
      final ProviderContainer local = ProviderContainer(
        overrides: <Override>[
          reviewServiceProvider.overrideWithValue(service),
          socialServiceProvider.overrideWithValue(FakeSocialService()),
        ],
      );
      addTearDown(local.dispose);
      await local.read(friendsProvider.future);
      local
          .read(reviewMarkersProvider.notifier)
          .update(const Camera(target: spot, zoom: 16), const Size(400, 800));
      await pumpEventQueue();
      final List<ReviewMarker> markers = local.read(reviewMarkersProvider);
      expect(markers, hasLength(1));
      expect(markers.single.placeKey, ReviewPlace.keyFor('sample-willow-park'));
      expect(markers.single.hasFriendReview, isTrue);
    });
  });
}
