import '../../core/utils/currency.dart';
import 'price_range.dart';
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

  /// Reviews that reported a per-person price.
  List<Review> get pricedReviews => reviews
      .where((Review review) => review.priceAmount != null)
      .toList(growable: false);

  /// Whether any review reported a price.
  bool get hasPrice =>
      reviews.any((Review review) => review.priceAmount != null);

  /// The ISO-4217 code most price reviews were reported in — the choice the
  /// average is computed in. Reviews in another currency are left out (see
  /// [averagePriceAmount]); `null` when only free prices (or none) were
  /// reported.
  String? get majorityPriceCurrency {
    final Map<String, int> counts = <String, int>{};
    String? best;
    for (final Review review in reviews) {
      final double? amount = review.priceAmount;
      final String? code = review.priceCurrency;
      if (amount == null || amount <= 0 || code == null) {
        continue;
      }
      final int count = (counts[code] ?? 0) + 1;
      counts[code] = count;
      if (best == null) {
        best = code;
      } else {
        final int bestCount = counts[best] ?? 0;
        if (count > bestCount ||
            (count == bestCount && code.compareTo(best) < 0)) {
          best = code;
        }
      }
    }
    return best;
  }

  /// The mean per-person amount across the reviews in the
  /// [majorityPriceCurrency] (plus free `0` prices, which are currency-agnostic).
  /// Reviews in a different currency are dropped. `null` when nothing usable was
  /// reported.
  double? get averagePriceAmount {
    final String? code = majorityPriceCurrency;
    double sum = 0;
    int count = 0;
    for (final Review review in reviews) {
      final double? amount = review.priceAmount;
      if (amount == null) {
        continue;
      }
      if (amount <= 0) {
        count++;
        continue;
      }
      if (code != null && review.priceCurrency == code) {
        sum += amount;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  /// The currency the average price is expressed in, or `null` when only free
  /// prices were reported.
  CurrencyInfo? get averagePriceCurrency {
    final String? code = majorityPriceCurrency;
    return code == null ? null : currencyInfoForCode(code);
  }

  /// The average price as a band to show (`€€€`), or `null` when nobody
  /// reported a usable one.
  PriceRange? get averagePrice {
    final double? amount = averagePriceAmount;
    if (amount == null) {
      return null;
    }
    if (amount <= 0) {
      return PriceRange.free;
    }
    return PriceRange.fromValue(amount, averagePriceCurrency);
  }

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
