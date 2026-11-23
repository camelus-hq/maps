import '../../core/utils/currency.dart';

/// A per-person price band for a place that charges one, e.g. a restaurant, a
/// café, a museum or a theme park.
///
/// [free] is a real answer for the places that charge nothing, so the composer
/// can always satisfy the (non-optional) price question. The paid bands are
/// **amount bands**: the wire carries a concrete per-person **amount and
/// currency** (see `docs/nostr-nips.md`), and [fromValue] maps that amount back
/// to a band for display. The band boundaries are euro-denominated separators
/// scaled per currency, so a yen band is `"¥1,700–4,100"` and the euro one is
/// `"€10–25"`.
enum PriceRange {
  /// No charge — "Free of charge".
  free,

  /// One symbol, the cheapest paid band.
  inexpensive,

  /// Two symbols.
  moderate,

  /// Three symbols.
  expensive,

  /// Four symbols.
  veryExpensive,

  /// Five symbols, the most expensive band.
  luxury;

  /// All paid bands (everything but [free]).
  static const List<PriceRange> paid = <PriceRange>[
    inexpensive,
    moderate,
    expensive,
    veryExpensive,
    luxury,
  ];

  /// The highest level (`5` = `€€€€€`).
  static const int maxLevel = 5;

  /// How many currency symbols this level draws (`0` for [free]).
  int get level => index;

  /// Whether this level means the place charges nothing.
  bool get isFree => this == PriceRange.free;

  /// The short form for a review row: `"Free"` or the currency symbol repeated
  /// [level] times (`"€"` … `"€€€€€"`).
  String shortLabel(String currencySymbol) =>
      isFree ? 'Free' : currencySymbol * level;

  /// The understandable form the composer and the place sheet explain: the
  /// per-person band as an **amount in the place's currency** (`"Free of
  /// charge"`, `"≤ €10"`, `"€10–25"`, `"€25–50"`, `"€50–100"`, `"€100+"`).
  String valueLabel(CurrencyInfo currency) {
    if (isFree) {
      return 'Free of charge';
    }
    final String symbol = currency.symbol;
    final String t1 = _amount(_threshold(0, currency));
    final String t2 = _amount(_threshold(1, currency));
    final String t3 = _amount(_threshold(2, currency));
    final String t4 = _amount(_threshold(3, currency));
    return switch (level) {
      1 => '≤ $symbol$t1',
      2 => '$symbol$t1–$t2',
      3 => '$symbol$t2–$t3',
      4 => '$symbol$t3–$t4',
      _ => '$symbol$t4+',
    };
  }

  /// The representative **amount** to publish for this band in [currency]
  /// (the band's midpoint, scaled; `0` for [free]).
  ///
  /// It always lands back inside the same band under [fromValue], so a
  /// published amount round-trips to the band the reviewer picked.
  double representativeAmount(CurrencyInfo currency) {
    if (isFree) {
      return 0;
    }
    final double euroLower = level == 1 ? 0 : _separators[level - 2];
    final double euro = level == maxLevel
        ? euroLower * 1.5
        : (euroLower + _separators[level - 1]) / 2;
    final double amount = euro * currency.scale;
    return amount < 1 ? amount : amount.roundToDouble();
  }

  /// The band an [amount] of [currency] falls in, or `null` when the amount or
  /// currency is unusable (negative, non-finite, no currency for a paid value).
  static PriceRange? fromValue(double? amount, CurrencyInfo? currency) {
    if (amount == null || !amount.isFinite || amount < 0) {
      return null;
    }
    if (amount == 0) {
      return PriceRange.free;
    }
    if (currency == null || currency.scale <= 0) {
      return null;
    }
    if (amount <= _threshold(0, currency)) {
      return PriceRange.inexpensive;
    }
    if (amount <= _threshold(1, currency)) {
      return PriceRange.moderate;
    }
    if (amount <= _threshold(2, currency)) {
      return PriceRange.expensive;
    }
    if (amount <= _threshold(3, currency)) {
      return PriceRange.veryExpensive;
    }
    return PriceRange.luxury;
  }

  /// The euro-denominated separators between the bands.
  static const List<double> _separators = <double>[10, 25, 50, 100];

  /// The [index]th separator in [currency], rounded to a readable amount — the
  /// same number [valueLabel] prints, so display and interpretation agree.
  static int _threshold(int index, CurrencyInfo currency) =>
      _nice(_separators[index] * currency.scale);

  /// A round, human amount: `10`, `25`, `1,700`, `16,000`.
  static String _amount(int value) {
    final String digits = value.toString();
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  static int _nice(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1000) {
      return (value / 100).round() * 100;
    }
    if (value >= 100) {
      return (value / 10).round() * 10;
    }
    if (value >= 20) {
      return (value / 5).round() * 5;
    }
    return value.round();
  }

  /// Parses a control-channel `price` parameter (a band level `0`–`5`) into a
  /// band, or `null` when it is missing, malformed or out of range.
  static PriceRange? fromLevel(Object? raw) {
    final int? level = switch (raw) {
      final PriceRange value => value.level,
      final int value => value,
      final double value =>
        value == value.roundToDouble() ? value.toInt() : null,
      final String value => int.tryParse(value.trim()),
      _ => null,
    };
    if (level == null || level < 0 || level > maxLevel) {
      return null;
    }
    return PriceRange.values[level];
  }
}

/// Whether a place of [category] charges a per-person price we should ask about
/// in a review (a meal, a ticket, an entry fee).
///
/// Deliberately conservative and phrase-based: it matches the food/drink and
/// paid-attraction words a geocoder returns ("Restaurant", "Coffee shop",
/// "Museum", "Theme park") and leaves free landmarks out ("Monument",
/// "Viewpoint", "National park"). Unknown or free categories return `false`, so
/// the price question only appears where it makes sense.
bool priceRangeAppliesToCategory(String? category) {
  final String value = _normalise(category);
  if (value.isEmpty) {
    return false;
  }
  // A landmark word wins: "Westminster Abbey" is free to look at, even when the
  // string also contains something that would otherwise look priced.
  for (final String word in _notPriced) {
    if (_containsWord(value, word)) {
      return false;
    }
  }
  for (final String phrase in _priced) {
    if (_containsWord(value, phrase)) {
      return true;
    }
  }
  return false;
}

/// Lower-cases [category] and collapses every separator (space, `_`, `-`, `/`)
/// to a single space, so the phrase list matches any provider's spelling.
String _normalise(String? category) {
  if (category == null) {
    return '';
  }
  return category.toLowerCase().replaceAll(_separators, ' ').trim();
}

final RegExp _separators = RegExp(r'[^a-z0-9]+');

bool _containsWord(String haystack, String word) {
  final int index = haystack.indexOf(word);
  if (index < 0) {
    return false;
  }
  final bool startOk = index == 0 || haystack.codeUnitAt(index - 1) == 0x20;
  final int end = index + word.length;
  final bool endOk = end == haystack.length || haystack.codeUnitAt(end) == 0x20;
  return startOk && endOk;
}

/// Categories that are genuinely free to visit — never asked about.
const List<String> _notPriced = <String>[
  'monument',
  'memorial',
  'viewpoint',
  'landmark',
  'statue',
  'artwork',
  'fountain',
  'square',
];

/// Categories that charge a per-person price. The food/drink words cover a
/// meal; the attraction words cover an entry ticket.
const List<String> _priced = <String>[
  // Food & drink.
  'restaurant',
  'bistro',
  'brasserie',
  'diner',
  'eatery',
  'grill',
  'steakhouse',
  'pizzeria',
  'pizza',
  'sushi',
  'ramen',
  'noodle',
  'barbecue',
  'bbq',
  'burger',
  'hamburger',
  'taco',
  'tapas',
  'cafe',
  'cafeteria',
  'coffee',
  'espresso',
  'tea house',
  'tea room',
  'patisserie',
  'ice cream',
  'gelato',
  'dessert',
  'bar',
  'pub',
  'biergarten',
  'beer garden',
  'brewery',
  'brewpub',
  'taproom',
  'wine bar',
  'cocktail',
  'nightclub',
  'night club',
  'karaoke',
  'fast food',
  'food court',
  'buffet',
  'canteen',
  'deli',
  'delicatessen',
  'snack bar',
  'juice bar',
  // Paid attractions & entertainment.
  'cinema',
  'movie theater',
  'movie theatre',
  'theater',
  'theatre',
  'opera',
  'opera house',
  'museum',
  'gallery',
  'zoo',
  'aquarium',
  'theme park',
  'amusement park',
  'amusement arcade',
  'arcade',
  'water park',
  'waterpark',
  'funfair',
  'fairground',
  'planetarium',
  'observatory',
  'casino',
  'stadium',
  'arena',
  'concert hall',
  'music venue',
  'events venue',
  'exhibition',
  'spa',
  'thermal bath',
  'thermal',
  'sauna',
  'bath house',
  'public bath',
  'swimming pool',
  'pool hall',
  'bowling',
  'bowling alley',
  'escape room',
  'trampoline',
  'climbing',
  'laser tag',
  'paintball',
  'karting',
  'go kart',
  'mini golf',
  'golf',
  'science centre',
  'science center',
  'tourist attraction',
  'attraction',
  'amusement',
  'water slide',
  'ski resort',
  'ski lift',
  'wildlife park',
  'safari park',
  'petting zoo',
];
