import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/review.dart';
import 'package:openmaps/domain/entities/review_bounds.dart';
import 'package:openmaps/domain/entities/review_draft.dart';
import 'package:openmaps/domain/entities/review_place.dart';

void main() {
  final String coffee = ReviewPlace.keyFor('sample-harbour-coffee');

  test('seeds demo reviews for the sample places', () async {
    final FakeReviewService service = FakeReviewService();
    final List<Review> reviews = await service.reviewsForPlace(coffee);
    expect(reviews, hasLength(3));
    expect(reviews.every((Review r) => r.placeKey == coffee), isTrue);
  });

  test('reviewsInBounds only returns what is on screen', () async {
    final FakeReviewService service = FakeReviewService();
    final List<Review> nearby = await service.reviewsInBounds(
      const ReviewBounds(north: 52.53, south: 52.51, east: 13.42, west: 13.39),
    );
    expect(nearby, isNotEmpty);
    expect(
      nearby.every(
        (Review r) =>
            r.position.latitude >= 52.51 && r.position.latitude <= 52.53,
      ),
      isTrue,
    );
    final List<Review> farAway = await service.reviewsInBounds(
      const ReviewBounds(north: 0.01, south: -0.01, east: 0.01, west: -0.01),
    );
    expect(farAway, isEmpty);
  });

  test('publishing replaces the same author\'s earlier review', () async {
    final FakeReviewService service = FakeReviewService();
    await service.publishReview(
      ReviewDraft(
        placeKey: coffee,
        position: const LatLon(52.5210, 13.4075),
        rating: 0.6,
        text: 'First go',
      ),
    );
    await service.publishReview(
      ReviewDraft(
        placeKey: coffee,
        position: const LatLon(52.5210, 13.4075),
        rating: 1.0,
        text: 'Changed my mind',
      ),
    );
    final List<Review> mine = (await service.reviewsForPlace(coffee))
        .where((Review r) => r.authorPubkey == FakeReviewService.demoUserPubkey)
        .toList();
    expect(mine, hasLength(1));
    expect(mine.single.rating, 1.0);
    expect(mine.single.content, 'Changed my mind');
    expect(service.published, hasLength(2));
  });

  test('published photos become links in the content', () async {
    final FakeReviewService service = FakeReviewService();
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    await service.publishReview(
      ReviewDraft(
        placeKey: coffee,
        position: const LatLon(52.5210, 13.4075),
        rating: 0.8,
        text: 'With a photo',
        photos: <ReviewPhoto>[ReviewPhoto(data: bytes)],
      ),
    );
    final Review mine = (await service.reviewsForPlace(coffee)).firstWhere(
      (Review r) => r.authorPubkey == FakeReviewService.demoUserPubkey,
    );
    expect(mine.photos, hasLength(1));
    expect(mine.photos.single, startsWith('https://blossom.example/'));
    expect(mine.content, contains(mine.photos.single));
    expect(mine.bodyText, 'With a photo');
    expect(service.uploaded, hasLength(1));
  });

  test('a signed-out service refuses to publish', () async {
    final FakeReviewService service = FakeReviewService(signedIn: false);
    await expectLater(
      service.publishReview(
        ReviewDraft(
          placeKey: coffee,
          position: const LatLon(52.5210, 13.4075),
          rating: 0.8,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
  });

  test('seed injects a review for the demo/control channel', () async {
    final FakeReviewService service = FakeReviewService();
    service.seed(
      Review(
        id: 'seeded',
        authorPubkey:
            '9000000000000000000000000000000000000000000000000000000000000009',
        placeKey: ReviewPlace.keyFor('sample-city-library'),
        rating: 0.9,
        content: 'Great reading room',
        position: const LatLon(52.5195, 13.4120),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final List<Review> reviews = await service.reviewsForPlace(
      ReviewPlace.keyFor('sample-city-library'),
    );
    expect(reviews.single.id, 'seeded');
  });
}
