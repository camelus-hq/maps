import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/osm_payments.dart';

/// The OSM `payment:*` reader: it must surface only what a place accepts and
/// never invent a method from a negative tag.
void main() {
  test('splits accepted from declined payment tags', () {
    final List<OsmPaymentMethod> methods = OsmPaymentCatalog.accepted(
      <String, String>{
        'payment:cash': 'yes',
        'payment:credit_cards': 'no',
        'payment:girocard': 'only',
        'payment:visa': 'yes',
        'wheelchair': 'yes',
        'opening_hours': 'Mo-Fr 09:00-18:00',
      },
    );
    expect(methods.map((OsmPaymentMethod m) => m.suffix).toList(), <String>[
      'cash',
      'girocard',
      'visa',
    ]);
  });

  test('drops negative and empty values, keeps interval', () {
    expect(OsmPaymentCatalog.isAccepted('yes'), isTrue);
    expect(OsmPaymentCatalog.isAccepted('only'), isTrue);
    expect(OsmPaymentCatalog.isAccepted('Mo-Fr 09:00-18:00'), isTrue);
    expect(OsmPaymentCatalog.isAccepted('No'), isFalse);
    expect(OsmPaymentCatalog.isAccepted('0'), isFalse);
    expect(OsmPaymentCatalog.isAccepted('  '), isFalse);
    expect(OsmPaymentCatalog.isAccepted(null), isFalse);
  });

  test('ignores sub-keys and non-payment tags', () {
    final List<OsmPaymentMethod> methods = OsmPaymentCatalog.accepted(
      <String, String>{
        'payment:cash:denominations': '5 EUR',
        'payment:': 'yes',
        'name': 'Cash Corner',
        'fee': 'yes',
      },
    );
    expect(methods, isEmpty);
  });

  test('names known methods and derives labels for unknown ones', () {
    expect(OsmPaymentCatalog.labelFor('girocard'), 'Girocard');
    expect(OsmPaymentCatalog.labelFor('american_express'), 'American Express');
    expect(OsmPaymentCatalog.labelFor('frobcoin'), 'Frobcoin');
  });

  test('orders known methods first, then unknown alphabetically', () {
    final List<OsmPaymentMethod> methods = OsmPaymentCatalog.accepted(
      <String, String>{
        'payment:zzz_custom': 'yes',
        'payment:visa': 'yes',
        'payment:aaa_custom': 'yes',
        'payment:cash': 'yes',
      },
    );
    expect(methods.map((OsmPaymentMethod m) => m.suffix).toList(), <String>[
      'cash',
      'visa',
      'aaa_custom',
      'zzz_custom',
    ]);
  });

  test('promotes lightning and cashu methods', () {
    final List<OsmPaymentMethod> promoted = OsmPaymentCatalog.promotedCrypto(
      <String, String>{
        'payment:lightning': 'yes',
        'payment:lightning_contactless': 'yes',
        'payment:cashu': 'yes',
        'payment:ecash': 'no',
        'payment:cash': 'yes',
      },
    );
    expect(promoted.map((OsmPaymentMethod m) => m.suffix), <String>[
      'lightning',
      'lightning_contactless',
      'cashu',
    ]);
    expect(promoted.first.isLightning, isTrue);
    expect(promoted[2].isCashu, isTrue);
    expect(promoted.first.isPromotedCrypto, isTrue);
  });
}
