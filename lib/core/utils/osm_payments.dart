/// Interprets OpenStreetMap `payment:*` tags into the payment methods a place
/// actually accepts.
///
/// OSM tags payment methods as `payment:<method>=yes|no|only|interval` (see
/// <https://wiki.openstreetmap.org/wiki/Key:payment:*>). This reader keeps only
/// the *accepted* methods — the sheet shows what a place takes, never the long
/// tail of what it does not — and gives each one a readable label so the UI can
/// attach an icon and a tooltip.
///
/// Pure Dart (no Flutter): the icon mapping lives in the presentation layer, so
/// the domain and this helper stay free of `dart:ui`.
library;

/// One accepted `payment:*` value found on a place.
class OsmPaymentMethod {
  const OsmPaymentMethod({
    required this.key,
    required this.suffix,
    required this.label,
    required this.value,
  });

  /// The full OSM tag key, e.g. `payment:visa`.
  final String key;

  /// The method part of the key, e.g. `visa`.
  final String suffix;

  /// A human-readable name for a tooltip, e.g. `Visa`.
  final String label;

  /// The raw OSM value: `yes`, `only`, or an `opening_hours` interval.
  final String value;

  /// Whether this method is a Bitcoin Lightning one (`payment:lightning` or
  /// `payment:lightning_contactless`) — promoted below the rating.
  bool get isLightning =>
      suffix == 'lightning' || suffix == 'lightning_contactless';

  /// Whether this method is a Chaumian ecash one (`payment:cashu` or
  /// `payment:ecash`) — promoted below the rating.
  bool get isCashu => suffix == 'cashu' || suffix == 'ecash';

  /// Whether this method is one of the crypto methods the sheet promotes below
  /// the overall review, rather than only listing in the Overview.
  bool get isPromotedCrypto => isLightning || isCashu;

  @override
  String toString() => 'OsmPaymentMethod($key=$value)';
}

/// The known `payment:*` methods, with a display label and a stable order.
///
/// Keys not listed here are still shown — [OsmPaymentCatalog.accepted] derives a
/// readable label from the key — so an uncommon or newly introduced method is
/// never silently dropped. The order of this map is the order the sheet lists
/// the known methods in (cash and the broad card groups first).
abstract final class OsmPaymentCatalog {
  static const String prefix = 'payment:';

  /// Values that mean "not accepted" (everything else counts as accepted).
  static const Set<String> _negative = <String>{
    '',
    'no',
    'false',
    '0',
    'none',
    'never',
  };

  /// `payment:<method>` suffixes with a label, in listing order.
  static const Map<String, String> labels = <String, String>{
    // Generic.
    'cash': 'Cash',
    'coins': 'Coins',
    'notes': 'Banknotes',
    'cheque': 'Cheque',
    'cards': 'Cards',
    'debit_cards': 'Debit cards',
    'credit_cards': 'Credit cards',
    'contactless': 'Contactless',
    'qr_code': 'QR code',
    'membership_card': 'Membership card',
    'electronic_purses': 'Electronic purse',
    'stored_value_card': 'Stored-value card',
    // Debit cards.
    'bancomat': 'Bancomat',
    'bancontact': 'Bancontact',
    'bankaxept': 'BankAxept',
    'cb': 'Carte Bancaire',
    'dankort': 'Dankort',
    'eftpos': 'EFTPOS',
    'eps': 'EPS',
    'girocard': 'Girocard',
    'interac': 'Interac',
    'maestro': 'Maestro',
    'mastercard_debit': 'Debit Mastercard',
    'mir': 'Mir',
    'multibanco': 'Multibanco',
    'multicaixa': 'Multicaixa',
    'napas': 'NAPAS',
    'nets': 'NETS',
    'postfinance_card': 'PostFinance Card',
    'troy': 'Troy',
    'unionpay_debit': 'UnionPay Debit',
    'visa_debit': 'Visa Debit',
    'gpn_debit': 'GPN Debit',
    // Credit cards.
    'visa': 'Visa',
    'mastercard': 'Mastercard',
    'american_express': 'American Express',
    'amex': 'American Express',
    'diners_club': 'Diners Club',
    'discover_card': 'Discover',
    'discover': 'Discover',
    'jcb': 'JCB',
    'unionpay': 'UnionPay',
    'elo': 'Elo',
    'belkart': 'Belkart',
    'dinacard': 'Dinacard',
    'forbrugsforeningen': 'Forbrugsforeningen',
    'golden_crown': 'Zolotaya Korona',
    // Digital wallets / mobile payment apps.
    'paypal': 'PayPal',
    'apple_pay': 'Apple Pay',
    'google_pay': 'Google Pay',
    'google_wallet': 'Google Wallet',
    'samsung_pay': 'Samsung Pay',
    'amazon_pay': 'Amazon Pay',
    'alipay': 'Alipay',
    'wechat': 'WeChat Pay',
    'wechat_pay': 'WeChat Pay',
    'line_pay': 'LINE Pay',
    'kakao_pay': 'Kakao Pay',
    'venmo': 'Venmo',
    'cash_app': 'Cash App',
    'bitpay': 'BitPay',
    'satispay': 'Satispay',
    'twint': 'TWINT',
    'swish': 'Swish',
    'vipps': 'Vipps',
    'mobilepay': 'MobilePay',
    'blik': 'BLIK',
    'mb_way': 'MB WAY',
    'payconiq': 'Payconiq',
    'klarna': 'Klarna',
    'afterpay': 'Afterpay',
    'revolut': 'Revolut',
    'grabpay': 'GrabPay',
    'gopay': 'GoPay',
    'dana': 'DANA',
    'ovo': 'OVO',
    'shopeepay': 'ShopeePay',
    'pix': 'Pix',
    'yape': 'Yape',
    'plin': 'Plin',
    'mercado_pago': 'Mercado Pago',
    'mercado_pago_qr': 'Mercado Pago QR',
    'satispay_qr': 'Satispay QR',
    // Fuel cards.
    'fuel_cards': 'Fuel cards',
    'dkv': 'DKV Card',
    'uta': 'UTA Card',
    'routex': 'Routex',
    'euroshell': 'EuroShell',
    'fleetcor': 'Fleetcor',
    // Cryptocurrencies.
    'bitcoin': 'Bitcoin',
    'lightning': 'Bitcoin Lightning',
    'lightning_contactless': 'Lightning (contactless)',
    'cashu': 'Cashu',
    'ecash': 'Ecash',
    'lightning_cashu': 'Cashu',
    'ethereum': 'Ethereum',
    'litecoin': 'Litecoin',
    'monero': 'Monero',
    'dogecoin': 'Dogecoin',
    'dash': 'Dash',
    'zcash': 'Zcash',
    'usdt': 'Tether',
  };

  /// Whether an OSM `payment:*` value means the method is accepted.
  ///
  /// `yes`/`only`/`interval` (and any positive spelling) count; `no`, `false`,
  /// `0`, `none` and an empty value do not. Values are trimmed and
  /// case-insensitive.
  static bool isAccepted(String? value) {
    if (value == null) {
      return false;
    }
    return !_negative.contains(value.trim().toLowerCase());
  }

  /// A readable label for a method suffix, deriving one from the key when it is
  /// not in the catalog (`google_wallet` → `Google wallet`).
  static String labelFor(String suffix) {
    final String? known = labels[suffix];
    if (known != null) {
      return known;
    }
    final String words = suffix.replaceAll('_', ' ').trim();
    if (words.isEmpty) {
      return suffix;
    }
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  /// The accepted `payment:*` methods in [tags], in catalog order (known keys
  /// first, then any others alphabetically by key), each with a unique suffix.
  static List<OsmPaymentMethod> accepted(Map<String, String> tags) {
    final Map<String, OsmPaymentMethod> found = <String, OsmPaymentMethod>{};
    for (final MapEntry<String, String> entry in tags.entries) {
      final String key = entry.key.trim();
      if (!key.startsWith(prefix)) {
        continue;
      }
      final String suffix = key.substring(prefix.length).trim().toLowerCase();
      // `payment:*:denominations`-style sub-keys are not methods themselves.
      if (suffix.isEmpty || suffix.contains(':')) {
        continue;
      }
      if (!isAccepted(entry.value)) {
        continue;
      }
      found.putIfAbsent(
        suffix,
        () => OsmPaymentMethod(
          key: key,
          suffix: suffix,
          label: labelFor(suffix),
          value: entry.value.trim(),
        ),
      );
    }
    final List<String> known = labels.keys
        .where(found.containsKey)
        .toList(growable: false);
    final List<String> unknown =
        found.keys
            .where((String suffix) => !labels.containsKey(suffix))
            .toList()
          ..sort();
    return <OsmPaymentMethod>[
      for (final String suffix in known) found[suffix]!,
      for (final String suffix in unknown) found[suffix]!,
    ];
  }

  /// The accepted methods the sheet promotes below the review
  /// (`payment:lightning`, `payment:lightning_contactless`, `payment:cashu`,
  /// `payment:ecash`).
  static List<OsmPaymentMethod> promotedCrypto(Map<String, String> tags) =>
      accepted(tags)
          .where((OsmPaymentMethod method) => method.isPromotedCrypto)
          .toList(growable: false);
}
