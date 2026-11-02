import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/review_marker_image.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/review_marker.dart';

/// The review badge is drawn locally ("★ 4.8 · 3 friends"). It must always
/// produce a PNG for a friend or a plain badge, and cache by label + variant.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool isPng(Uint8List bytes) =>
      bytes.length > 8 && bytes.sublist(0, 4).join(',') == '137,80,78,71';

  ReviewMarker marker({
    double rating = 0.96,
    int count = 12,
    int friends = 0,
  }) => ReviewMarker(
    placeKey: 'openstreetmap:way/1',
    position: const LatLon(52.52, 13.405),
    averageRating: rating,
    reviewCount: count,
    friendCount: friends,
    topFriendName: friends > 0 ? 'Mia' : null,
  );

  test('draws a highlighted badge for a friend-reviewed place', () async {
    final ReviewMarkerComposer composer = ReviewMarkerComposer();
    addTearDown(composer.dispose);
    final Uint8List bytes = await composer.compose(
      marker(friends: 3, count: 5),
    );
    expect(isPng(bytes), isTrue);
    expect(composer.cachedBytes(marker(friends: 3, count: 5)), isNotNull);
  });

  test('draws a plain badge when no friend has reviewed', () async {
    final ReviewMarkerComposer composer = ReviewMarkerComposer();
    addTearDown(composer.dispose);
    final Uint8List bytes = await composer.compose(marker());
    expect(isPng(bytes), isTrue);
  });

  test('badge labels read as in the reference app', () {
    expect(marker(friends: 3, count: 5).badgeLabel, '4.8 · 3 friends');
    expect(marker(friends: 1, count: 5).badgeLabel, '4.8 · 1 friend');
    expect(marker(count: 12).badgeLabel, '4.8 · 12');
    expect(marker(friends: 3, count: 5).hasFriendReview, isTrue);
    expect(marker(count: 12).hasFriendReview, isFalse);
  });

  test('a zero rating still composes', () async {
    final ReviewMarkerComposer composer = ReviewMarkerComposer();
    addTearDown(composer.dispose);
    final Uint8List bytes = await composer.compose(
      marker(rating: 0, count: 0, friends: 0),
    );
    expect(isPng(bytes), isTrue);
  });
}
