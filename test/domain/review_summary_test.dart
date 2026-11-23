import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/price_range.dart';
import 'package:openmaps/domain/entities/review.dart';
import 'package:openmaps/domain/entities/review_summary.dart';

/// The aggregate drops reviews reported in a currency other than the majority,
/// so a stray dollar review cannot skew a euro place's price band.
void main() {
  const String placeKey = 'openstreetmap:node/1';
  const LatLon at = LatLon(52.52, 13.405);
  const String author =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Review review({
    required String id,
    double? priceAmount,
    String? priceCurrency,
  }) => Review(
    id: id,
    authorPubkey: author,
    placeKey: placeKey,
    rating: 0.8,
    content: 'x',
    position: at,
    createdAt: DateTime.utc(2026),
    priceAmount: priceAmount,
    priceCurrency: priceCurrency,
  );

  test('averages in the majority currency and drops the others', () {
    final ReviewSummary summary = ReviewSummary(
      placeKey: placeKey,
      reviews: <Review>[
        review(id: '1', priceAmount: 10, priceCurrency: 'EUR'),
        review(id: '2', priceAmount: 20, priceCurrency: 'EUR'),
        review(id: '3', priceAmount: 100, priceCurrency: 'USD'),
        review(id: '4', priceAmount: 0), // free, currency-agnostic
        review(id: '5'), // no price at all
      ],
    );
    expect(summary.hasPrice, isTrue);
    expect(summary.majorityPriceCurrency, 'EUR');
    // (10 + 20 + 0) / 3 — the USD review is excluded.
    expect(summary.averagePriceAmount, 10);
    expect(summary.averagePriceCurrency?.code, 'EUR');
    expect(summary.averagePrice, PriceRange.inexpensive);
  });

  test('a currency tie breaks deterministically', () {
    final ReviewSummary summary = ReviewSummary(
      placeKey: placeKey,
      reviews: <Review>[
        review(id: '1', priceAmount: 40, priceCurrency: 'USD'),
        review(id: '2', priceAmount: 40, priceCurrency: 'EUR'),
      ],
    );
    expect(summary.majorityPriceCurrency, 'EUR');
    expect(summary.averagePrice, PriceRange.expensive);
  });

  test('only-free prices average to free', () {
    final ReviewSummary summary = ReviewSummary(
      placeKey: placeKey,
      reviews: <Review>[
        review(id: '1', priceAmount: 0),
        review(id: '2', priceAmount: 0),
      ],
    );
    expect(summary.majorityPriceCurrency, isNull);
    expect(summary.averagePriceAmount, 0);
    expect(summary.averagePrice, PriceRange.free);
  });

  test('a paid price with no currency is ignored', () {
    final ReviewSummary summary = ReviewSummary(
      placeKey: placeKey,
      reviews: <Review>[
        review(id: '1', priceAmount: 50),
        review(id: '2', priceAmount: 18, priceCurrency: 'EUR'),
      ],
    );
    expect(summary.majorityPriceCurrency, 'EUR');
    expect(summary.averagePriceAmount, 18);
  });

  test('no prices means no aggregate', () {
    final ReviewSummary summary = ReviewSummary(
      placeKey: placeKey,
      reviews: <Review>[review(id: '1')],
    );
    expect(summary.hasPrice, isFalse);
    expect(summary.averagePrice, isNull);
  });
}
