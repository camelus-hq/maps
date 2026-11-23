import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/currency.dart';
import 'package:openmaps/domain/entities/price_range.dart';

/// The price level is the currency-agnostic half of the feature and the
/// category test is what keeps the question off landmarks.
void main() {
  const CurrencyInfo eur = CurrencyInfo('EUR', '€');
  const CurrencyInfo usd = CurrencyInfo('USD', r'$', scale: 1.1);
  const CurrencyInfo jpy = CurrencyInfo('JPY', '¥', scale: 165);

  group('levels', () {
    test('free is 0 and the paid bands count up to 5', () {
      expect(PriceRange.free.level, 0);
      expect(PriceRange.inexpensive.level, 1);
      expect(PriceRange.luxury.level, 5);
      expect(PriceRange.paid, hasLength(5));
      expect(PriceRange.paid.first, PriceRange.inexpensive);
    });

    test('short labels repeat the region symbol', () {
      expect(PriceRange.free.shortLabel('€'), 'Free');
      expect(PriceRange.inexpensive.shortLabel('€'), '€');
      expect(PriceRange.luxury.shortLabel('€'), '€€€€€');
      expect(PriceRange.expensive.shortLabel('£'), '£££');
    });

    test('value labels show the amount in the place currency', () {
      expect(PriceRange.free.valueLabel(eur), 'Free of charge');
      expect(PriceRange.inexpensive.valueLabel(eur), '≤ €10');
      expect(PriceRange.moderate.valueLabel(eur), '€10–25');
      expect(PriceRange.expensive.valueLabel(eur), '€25–50');
      expect(PriceRange.veryExpensive.valueLabel(eur), '€50–100');
      expect(PriceRange.luxury.valueLabel(eur), '€100+');
    });

    test('value labels scale and round for the currency', () {
      expect(PriceRange.inexpensive.valueLabel(jpy), '≤ ¥1,700');
      expect(PriceRange.moderate.valueLabel(jpy), '¥1,700–4,100');
      expect(PriceRange.luxury.valueLabel(jpy), '¥16,500+');
      expect(PriceRange.moderate.valueLabel(usd), r'$11–30');
    });

    test('fromValue maps an amount back to a band', () {
      expect(PriceRange.fromValue(null, eur), isNull);
      expect(PriceRange.fromValue(-1, eur), isNull);
      expect(PriceRange.fromValue(0, eur), PriceRange.free);
      expect(PriceRange.fromValue(5, eur), PriceRange.inexpensive);
      expect(PriceRange.fromValue(10, eur), PriceRange.inexpensive);
      expect(PriceRange.fromValue(18, eur), PriceRange.moderate);
      expect(PriceRange.fromValue(25, eur), PriceRange.moderate);
      expect(PriceRange.fromValue(40, eur), PriceRange.expensive);
      expect(PriceRange.fromValue(75, eur), PriceRange.veryExpensive);
      expect(PriceRange.fromValue(150, eur), PriceRange.luxury);
      // A paid value with no currency cannot be placed.
      expect(PriceRange.fromValue(18, null), isNull);
      // Same amount, different currency, different band.
      expect(PriceRange.fromValue(2900, jpy), PriceRange.moderate);
    });

    test('representativeAmount round-trips to the same band', () {
      for (final CurrencyInfo currency in <CurrencyInfo>[eur, usd, jpy]) {
        for (final PriceRange band in PriceRange.values) {
          final double amount = band.representativeAmount(currency);
          expect(
            PriceRange.fromValue(amount, currency),
            band,
            reason: '${band.name} in ${currency.code} (amount $amount)',
          );
        }
      }
      // Free publishes zero, with no currency.
      expect(PriceRange.free.representativeAmount(eur), 0);
      expect(PriceRange.free.representativeAmount(jpy), 0);
    });

    test('fromLevel accepts a tag string, int or double in 0..5', () {
      expect(PriceRange.fromLevel('0'), PriceRange.free);
      expect(PriceRange.fromLevel('3'), PriceRange.expensive);
      expect(PriceRange.fromLevel(2), PriceRange.moderate);
      expect(PriceRange.fromLevel(5.0), PriceRange.luxury);
      expect(PriceRange.fromLevel(PriceRange.moderate), PriceRange.moderate);
    });

    test('fromLevel rejects junk and out-of-range values', () {
      expect(PriceRange.fromLevel(null), isNull);
      expect(PriceRange.fromLevel('-1'), isNull);
      expect(PriceRange.fromLevel('6'), isNull);
      expect(PriceRange.fromLevel('free'), isNull);
      expect(PriceRange.fromLevel(2.5), isNull);
    });
  });

  group('category applicability', () {
    test('asks for food, drink and ticketed attractions', () {
      for (final String category in <String>[
        'Cafe',
        'Coffee shop',
        'Italian restaurant',
        'Fast food',
        'Bar',
        'Biergarten',
        'Ice cream',
        'Nightclub',
        'Museum',
        'Cinema',
        'Theatre',
        'Opera house',
        'Zoo',
        'Aquarium',
        'Theme park',
        'Tourist attraction',
        'Casino',
        'Bowling alley',
        'Public bath',
        'restaurant',
      ]) {
        expect(priceRangeAppliesToCategory(category), isTrue, reason: category);
      }
    });

    test('stays away from landmarks and free places', () {
      for (final String? category in <String?>[
        'Monument',
        'Memorial',
        'Viewpoint',
        'Landmark',
        'National park',
        'Park',
        'Garden',
        'Fountain',
        'Library',
        'Hotel',
        'Gas station',
        'Supermarket',
        'Church',
        'Town hall',
        'Bus station',
        'ATM',
        'Post office',
        'Street',
        null,
        '',
      ]) {
        expect(
          priceRangeAppliesToCategory(category),
          isFalse,
          reason: category,
        );
      }
    });

    test('a landmark word wins over a priced-looking word', () {
      expect(
        priceRangeAppliesToCategory('Monument to the cafe owner'),
        isFalse,
      );
      expect(priceRangeAppliesToCategory('Viewpoint restaurant'), isFalse);
    });
  });
}
