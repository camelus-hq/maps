import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_bounds.dart';
import '../../domain/entities/review_draft.dart';
import '../../domain/entities/review_place.dart';
import '../../domain/ports/review_service.dart';
import '../nostr/review_event.dart';
import 'fake_social_service.dart';

/// In-memory [ReviewService] so the app runs, and tests run, without relays.
///
/// Seeded with our own invented reviews (some by the demo friends) so the
/// place sheet and the map badges have something honest to show.
class FakeReviewService implements ReviewService {
  FakeReviewService({
    this.signedIn = true,
    List<Review>? reviews,
    DateTime Function()? clock,
  }) : _reviews = <Review>[...(reviews ?? demoReviews())],
       _clock = clock ?? DateTime.now;

  /// Every draft this fake was asked to publish (newest last).
  final List<ReviewDraft> published = <ReviewDraft>[];

  /// Every photo set uploaded (parallel to [published] when photos were sent).
  final List<List<String>> uploaded = <List<String>>[];

  /// When set, [publishReview] throws it (tests).
  AppException? publishError;

  /// Whether this fake reports a signed-in identity.
  bool signedIn;

  final List<Review> _reviews;
  final DateTime Function() _clock;

  /// The demo identity used in keyless runs.
  static const String demoUserPubkey = FakeSocialService.demoUserPubkey;

  @override
  bool get isLoggedIn => signedIn;

  @override
  String? get currentUserPubkey => signedIn ? demoUserPubkey : null;

  /// The keys of the demo friends, so seeded friend reviews line up with the
  /// fake social graph.
  static List<String> friendPubkeys() => <String>[
    for (final Friend friend in FakeSocialService.demoFriends) friend.pubkey,
  ];

  /// The reviews the fake starts with: a handful near the sample places, some
  /// written by the demo friends.
  static List<Review> demoReviews({DateTime? now}) {
    final DateTime base = now ?? DateTime.now();
    final String coffee = ReviewPlace.keyFor('sample-harbour-coffee');
    final String mill = ReviewPlace.keyFor('sample-old-mill-cafe');
    final String kitchen = ReviewPlace.keyFor('sample-riverside-kitchen');
    final List<String> friends = friendPubkeys();
    int seq = 0;
    Review make({
      required String placeKey,
      required String pubkey,
      required double rating,
      required String content,
      required LatLon position,
      required Duration ago,
      String? name,
    }) {
      seq++;
      return Review(
        id: 'demo-review-$seq',
        authorPubkey: pubkey,
        placeKey: placeKey,
        rating: rating,
        content: content,
        position: position,
        createdAt: base.subtract(ago),
        authorName: name,
      );
    }

    return <Review>[
      make(
        placeKey: coffee,
        pubkey: friends[0],
        rating: 1.0,
        content:
            'Best flat white in the neighbourhood — the window seats are '
            'worth the wait.',
        position: const LatLon(52.5210, 13.4075),
        ago: const Duration(days: 2, hours: 3),
        name: FakeSocialService.demoFriends[0].displayName,
      ),
      make(
        placeKey: coffee,
        pubkey: friends[1],
        rating: 0.8,
        content: 'Good food, friendly staff. A little noisy at lunchtime.',
        position: const LatLon(52.52105, 13.40755),
        ago: const Duration(days: 6),
        name: FakeSocialService.demoFriends[1].displayName,
      ),
      make(
        placeKey: coffee,
        pubkey:
            '9000000000000000000000000000000000000000000000000000000000000001',
        rating: 0.8,
        content: 'Solid coffee and pastries.',
        position: const LatLon(52.52098, 13.40744),
        ago: const Duration(days: 12),
        name: 'Jonas',
      ),
      make(
        placeKey: mill,
        pubkey: friends[2],
        rating: 1.0,
        content: 'Quiet courtyard, great for working.',
        position: const LatLon(52.5180, 13.4020),
        ago: const Duration(days: 1, hours: 5),
        name: FakeSocialService.demoFriends[2].displayName,
      ),
      make(
        placeKey: kitchen,
        pubkey:
            '9000000000000000000000000000000000000000000000000000000000000002',
        rating: 0.6,
        content: 'Tasty but the wait was long on a Friday.',
        position: const LatLon(52.5230, 13.4100),
        ago: const Duration(days: 4),
        name: 'Priya',
      ),
      make(
        placeKey: kitchen,
        pubkey:
            '9000000000000000000000000000000000000000000000000000000000000003',
        rating: 0.8,
        content: 'Nice riverside tables.',
        position: const LatLon(52.52304, 13.41006),
        ago: const Duration(days: 9),
        name: 'Marko',
      ),
    ];
  }

  @override
  Future<void> publishReview(ReviewDraft draft) async {
    if (!signedIn) {
      throw const ValidationException('Sign in to publish a review');
    }
    final AppException? error = publishError;
    if (error != null) {
      throw error;
    }
    final List<String> photoUrls = await uploadPhotos(draft.photos);
    if (photoUrls.isNotEmpty) {
      uploaded.add(photoUrls);
    }
    final List<String> allPhotos = <String>[...draft.photoUrls, ...photoUrls];
    final String content = ReviewEvent.composeContent(
      text: draft.text,
      photoUrls: allPhotos,
    );
    // A parameterised replaceable event: the same author + place replaces.
    _reviews.removeWhere(
      (Review review) =>
          review.authorPubkey == demoUserPubkey &&
          review.placeKey == draft.placeKey,
    );
    _reviews.add(
      Review(
        id: 'demo-published-${published.length + 1}',
        authorPubkey: demoUserPubkey,
        placeKey: draft.placeKey,
        rating: draft.rating,
        content: content,
        position: draft.position,
        createdAt: _clock().toUtc(),
        photos: allPhotos,
        authorName: 'You',
      ),
    );
    published.add(draft);
  }

  @override
  Future<List<Review>> reviewsForPlace(String placeKey) async {
    final String key = placeKey.trim();
    return List<Review>.unmodifiable(
      _reviews.where((Review review) => review.placeKey == key),
    );
  }

  @override
  Future<List<Review>> reviewsInBounds(ReviewBounds bounds) async {
    return List<Review>.unmodifiable(
      _reviews.where((Review review) => bounds.contains(review.position)),
    );
  }

  @override
  Future<List<String>> uploadPhotos(List<ReviewPhoto> photos) async {
    return <String>[
      for (final ReviewPhoto photo in photos.take(ReviewDraft.maxPhotos))
        if (!photo.isEmpty) 'https://blossom.example/${fakeSha256(photo.data)}',
    ];
  }

  /// Adds a review to the in-memory set (used by tests and the control
  /// channel's demo injection).
  void seed(Review review) {
    _reviews.removeWhere(
      (Review existing) =>
          existing.authorPubkey == review.authorPubkey &&
          existing.placeKey == review.placeKey,
    );
    _reviews.add(review);
  }

  /// All reviews currently held (diagnostics/tests).
  List<Review> get all => List<Review>.unmodifiable(_reviews);

  /// A deterministic 64-hex stand-in for a Blossom blob hash.
  static String fakeSha256(Uint8List data) {
    // A simple, stable mixing function — not a real hash, just a label.
    int h1 = 0x811c9dc5;
    int h2 = 0x1000193;
    for (final int byte in data) {
      h1 = (h1 ^ byte) * 0x01000193 & 0xFFFFFFFF;
      h2 = (h2 + byte * 0x9E3779B1) & 0xFFFFFFFF;
    }
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 8; i++) {
      h1 = (h1 * 0x01000193 + i) & 0xFFFFFFFF;
      h2 = (h2 ^ (h1 >> 3)) & 0xFFFFFFFF;
      buffer.write((h1 ^ h2).toRadixString(16).padLeft(8, '0'));
    }
    return buffer.toString();
  }
}
