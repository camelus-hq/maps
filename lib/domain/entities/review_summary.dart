import 'review.dart';

/// Every review known for one place, plus the aggregates the place sheet shows:
/// the average rating, how many friends have reviewed it, and the friend review
/// to headline.
///
/// A plain value object built by the state layer from the reviews it loaded, so
/// the UI never does the maths itself.
class ReviewSummary {
  const ReviewSummary({required this.placeKey, required this.reviews});

  /// An empty summary for a place nobody has reviewed yet.
  const ReviewSummary.empty(this.placeKey) : reviews = const <Review>[];

  /// The place key (`d` tag value) the reviews belong to.
  final String placeKey;

  /// The reviews, newest first.
  final List<Review> reviews;

  bool get isEmpty => reviews.isEmpty;

  bool get isNotEmpty => reviews.isNotEmpty;

  int get reviewCount => reviews.length;

  List<Review> get friendReviews =>
      reviews.where((Review review) => review.isFriend).toList(growable: false);

  int get friendCount => friendReviews.length;

  /// The average normalised rating in `0..1`, `0` when there are no reviews.
  double get averageRating {
    if (reviews.isEmpty) {
      return 0;
    }
    double sum = 0;
    for (final Review review in reviews) {
      sum += review.rating;
    }
    return sum / reviews.length;
  }

  /// The average on the 0–5 star scale (e.g. 4.8).
  double get stars => averageRating * 5;

  /// The headline review: the newest review by a friend, else the newest.
  Review? get headline {
    if (reviews.isEmpty) {
      return null;
    }
    for (final Review review in reviews) {
      if (review.isFriend) {
        return review;
      }
    }
    return reviews.first;
  }

  @override
  String toString() =>
      'ReviewSummary($placeKey, $reviewCount reviews, $friendCount friends)';
}
