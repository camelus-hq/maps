/// Region-aware currency for the per-person price ranges.
///
/// The price stored on a review is currency-agnostic (a level `0`–`5`, see
/// [PriceRange]). The **place's own region** — not the reader's locale —
/// supplies the currency, so a café in Berlin reads in euro even when the phone
/// is set to English, and the same review travels correctly between regions.
///
/// A [CurrencyInfo] carries the symbol the composer and the place sheet print,
/// and a coarse [CurrencyInfo.scale] (approximate local units per euro) used to
/// render the bands as understandable **amounts** ("€10–25", "¥1,600–4,000")
/// rather than bare symbols.
///
/// Pure Dart: it takes an ISO-3166 region *code*, so `lib/domain` can use it too.
library;

/// A currency: its ISO-4217 code, its symbol, and a coarse size guide.
class CurrencyInfo {
  const CurrencyInfo(this.code, this.symbol, {this.scale = 1});

  /// ISO-4217 code, e.g. `EUR`.
  final String code;

  /// The symbol printed before an amount, e.g. `€`, `$`, `¥`.
  final String symbol;

  /// Approximate local-currency units per euro (a coarse guide, not a live
  /// rate), used to turn the euro-denominated bands into local amounts.
  final double scale;

  @override
  bool operator ==(Object other) =>
      other is CurrencyInfo &&
      other.code == code &&
      other.symbol == symbol &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(code, symbol, scale);

  @override
  String toString() => 'CurrencyInfo($code, $symbol, scale: $scale)';
}

/// The currency used when a place's region is unknown.
const CurrencyInfo defaultCurrency = CurrencyInfo('EUR', '€');

/// The currency for an ISO-3166-1 alpha-2 [region] code, or `null` when the
/// region (or its currency) is unknown.
CurrencyInfo? currencyInfoForRegion(String? region) {
  if (region == null) {
    return null;
  }
  final String code = region.trim().toUpperCase();
  if (code.length != 2) {
    return null;
  }
  if (_euroRegions.contains(code)) {
    return _currencies['EUR'];
  }
  final String? currency = _regionCurrency[code];
  return currency == null ? null : _currencies[currency];
}

/// The currency for an ISO-4217 [code] (e.g. `EUR`), or `null` when the code is
/// unknown.
CurrencyInfo? currencyInfoForCode(String? code) {
  if (code == null) {
    return null;
  }
  final String value = code.trim().toUpperCase();
  if (value.length != 3) {
    return null;
  }
  return _currencies[value];
}

/// The currency for [region], falling back to [defaultCurrency] when the region
/// is unknown.
CurrencyInfo currencyForRegion(String? region) =>
    currencyInfoForRegion(region) ?? defaultCurrency;

/// The currency symbol for an ISO-3166-1 alpha-2 [region] code, or `null` when
/// the region is unknown.
String? currencySymbolForRegion(String? region) =>
    currencyInfoForRegion(region)?.symbol;

/// Euro-area members plus the euro-using microstates.
const Set<String> _euroRegions = <String>{
  'AD',
  'AT',
  'AX',
  'BE',
  'CY',
  'DE',
  'EE',
  'ES',
  'FI',
  'FR',
  'GR',
  'HR',
  'IE',
  'IT',
  'LT',
  'LU',
  'LV',
  'MC',
  'ME',
  'MT',
  'NL',
  'PT',
  'SI',
  'SK',
  'SM',
  'VA',
  'XK',
};

/// ISO-3166 alpha-2 region → ISO-4217 currency code. Only regions whose
/// currency we can render sensibly are listed; anything else falls back to the
/// default.
const Map<String, String> _regionCurrency = <String, String>{
  'US': 'USD',
  'CA': 'CAD',
  'AU': 'AUD',
  'NZ': 'NZD',
  'SG': 'SGD',
  'HK': 'HKD',
  'TW': 'TWD',
  'MX': 'MXN',
  'AR': 'ARS',
  'CL': 'CLP',
  'CO': 'COP',
  'BR': 'BRL',
  'GB': 'GBP',
  'GG': 'GBP',
  'IM': 'GBP',
  'JE': 'GBP',
  'GI': 'GBP',
  'FK': 'GBP',
  'EG': 'EGP',
  'CH': 'CHF',
  'LI': 'CHF',
  'JP': 'JPY',
  'CN': 'CNY',
  'KR': 'KRW',
  'IN': 'INR',
  'RU': 'RUB',
  'TR': 'TRY',
  'IL': 'ILS',
  'TH': 'THB',
  'VN': 'VND',
  'ID': 'IDR',
  'MY': 'MYR',
  'PH': 'PHP',
  'PK': 'PKR',
  'NG': 'NGN',
  'ZA': 'ZAR',
  'SE': 'SEK',
  'NO': 'NOK',
  'DK': 'DKK',
  'IS': 'ISK',
  'PL': 'PLN',
  'CZ': 'CZK',
  'HU': 'HUF',
  'RO': 'RON',
  'BG': 'BGN',
  'UA': 'UAH',
  'AE': 'AED',
  'SA': 'SAR',
};

/// ISO-4217 currency code → how it is printed and roughly how big it is.
///
/// The [CurrencyInfo.scale] is a coarse purchasing-power guide (local units per
/// euro), not a live exchange rate — it only makes the price bands readable.
const Map<String, CurrencyInfo> _currencies = <String, CurrencyInfo>{
  'EUR': CurrencyInfo('EUR', '€'),
  'USD': CurrencyInfo('USD', r'$', scale: 1.1),
  'CAD': CurrencyInfo('CAD', r'$', scale: 1.5),
  'AUD': CurrencyInfo('AUD', r'$', scale: 1.6),
  'NZD': CurrencyInfo('NZD', r'$', scale: 1.8),
  'SGD': CurrencyInfo('SGD', r'$', scale: 1.5),
  'HKD': CurrencyInfo('HKD', r'$', scale: 8.5),
  'TWD': CurrencyInfo('TWD', r'$', scale: 35),
  'MXN': CurrencyInfo('MXN', r'$', scale: 20),
  'ARS': CurrencyInfo('ARS', r'$', scale: 900),
  'CLP': CurrencyInfo('CLP', r'$', scale: 1000),
  'COP': CurrencyInfo('COP', r'$', scale: 4300),
  'BRL': CurrencyInfo('BRL', r'R$', scale: 6),
  'GBP': CurrencyInfo('GBP', '£', scale: 0.85),
  'EGP': CurrencyInfo('EGP', '£', scale: 55),
  'CHF': CurrencyInfo('CHF', 'CHF', scale: 1),
  'JPY': CurrencyInfo('JPY', '¥', scale: 165),
  'CNY': CurrencyInfo('CNY', '¥', scale: 7.8),
  'KRW': CurrencyInfo('KRW', '₩', scale: 1450),
  'INR': CurrencyInfo('INR', '₹', scale: 90),
  'RUB': CurrencyInfo('RUB', '₽', scale: 100),
  'TRY': CurrencyInfo('TRY', '₺', scale: 35),
  'ILS': CurrencyInfo('ILS', '₪', scale: 4),
  'THB': CurrencyInfo('THB', '฿', scale: 38),
  'VND': CurrencyInfo('VND', '₫', scale: 26000),
  'IDR': CurrencyInfo('IDR', 'Rp', scale: 17000),
  'MYR': CurrencyInfo('MYR', 'RM', scale: 5),
  'PHP': CurrencyInfo('PHP', '₱', scale: 60),
  'PKR': CurrencyInfo('PKR', '₨', scale: 300),
  'NGN': CurrencyInfo('NGN', '₦', scale: 1700),
  'ZAR': CurrencyInfo('ZAR', 'R', scale: 20),
  'SEK': CurrencyInfo('SEK', 'kr', scale: 11.5),
  'NOK': CurrencyInfo('NOK', 'kr', scale: 11.5),
  'DKK': CurrencyInfo('DKK', 'kr', scale: 7.5),
  'ISK': CurrencyInfo('ISK', 'kr', scale: 150),
  'PLN': CurrencyInfo('PLN', 'zł', scale: 4.3),
  'CZK': CurrencyInfo('CZK', 'Kč', scale: 25),
  'HUF': CurrencyInfo('HUF', 'Ft', scale: 400),
  'RON': CurrencyInfo('RON', 'lei', scale: 5),
  'BGN': CurrencyInfo('BGN', 'лв', scale: 2),
  'UAH': CurrencyInfo('UAH', '₴', scale: 45),
  'AED': CurrencyInfo('AED', 'د.إ', scale: 4),
  'SAR': CurrencyInfo('SAR', '﷼', scale: 4),
};
