import '../entities/review.dart';
import '../entities/review_bounds.dart';
import '../entities/review_place.dart';
import '../ports/review_service.dart';

/// Reads the reviews for one place, newest first.
class LoadPlaceReviews {
  const LoadPlaceReviews(this._service);

  final ReviewService _service;

  static const int maxReviews = 200;

  Future<List<Review>> call(String placeKey) async {
    if (!ReviewPlace.isValidKey(placeKey)) {
      return const <Review>[];
    }
    final List<Review> reviews = await _service.reviewsForPlace(placeKey);
    return sortNewest(reviews);
  }

  /// Sorts [reviews] newest first and caps the list.
  static List<Review> sortNewest(List<Review> reviews) {
    final List<Review> sorted = <Review>[...reviews]
      ..sort((Review a, Review b) => b.createdAt.compareTo(a.createdAt));
    if (sorted.length > maxReviews) {
      return sorted.sublist(0, maxReviews);
    }
    return List<Review>.unmodifiable(sorted);
  }
}

/// Reads the reviews under the geohash cells that cover the visible rectangle.
///
/// The service answers for the **whole covering cells** (a bounded superset);
/// the map controller clips that to the exact viewport itself, so it can cache
/// the result and serve a pan inside the same cells without another relay
/// query. The clip also keeps a relay that ignores the `#g` filter from flooding
/// the map with off-screen pins.
class LoadVisibleReviews {
  const LoadVisibleReviews(this._service);

  final ReviewService _service;

  /// Reviews whose position is at most this far outside the rectangle are kept
  /// by the caller, so a pin that is half on screen does not flicker.
  static const double edgeMarginDegrees = 0.002;

  Future<List<Review>> call(ReviewBounds bounds) async {
    final List<Review> reviews = await _service.reviewsInBounds(bounds);
    return LoadPlaceReviews.sortNewest(reviews);
  }
}
