import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/currency.dart';

/// Region-awareness is the point of the price range: the same stored level must
/// read in the *place's* currency, not the reader's locale.
void main() {
  group('currencyInfoForRegion', () {
    test('maps a region to its currency and symbol', () {
      expect(currencyInfoForRegion('DE')?.code, 'EUR');
      expect(currencyInfoForRegion('DE')?.symbol, '€');
      expect(currencyInfoForRegion('de')?.symbol, '€');
      expect(currencyInfoForRegion('US')?.code, 'USD');
      expect(currencyInfoForRegion('US')?.symbol, r'$');
      expect(currencyInfoForRegion('GB')?.symbol, '£');
      expect(currencyInfoForRegion('JP')?.symbol, '¥');
      expect(currencyInfoForRegion('BR')?.symbol, r'R$');
    });

    test('gives bigger currencies a proportionally bigger scale', () {
      expect(currencyInfoForRegion('JP')!.scale, greaterThan(100));
      expect(currencyInfoForRegion('DE')!.scale, 1);
    });

    test('unknown or malformed regions return null', () {
      expect(currencyInfoForRegion('ZZ'), isNull);
      expect(currencyInfoForRegion('D'), isNull);
      expect(currencyInfoForRegion(''), isNull);
      expect(currencyInfoForRegion(null), isNull);
    });
  });

  group('currencyForRegion', () {
    test('falls back to the default currency', () {
      expect(currencyForRegion('ZZ'), defaultCurrency);
      expect(currencyForRegion(null), defaultCurrency);
      expect(currencyForRegion('FR'), const CurrencyInfo('EUR', '€'));
    });
  });

  group('currencySymbolForRegion', () {
    test('returns just the symbol', () {
      expect(currencySymbolForRegion('FR'), '€');
      expect(currencySymbolForRegion('US'), r'$');
      expect(currencySymbolForRegion('ZZ'), isNull);
    });
  });
}
