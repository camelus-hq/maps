import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/features/common/place_result_icon.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

void main() {
  group('placeResultIcon', () {
    test('maps transit categories to their mode glyph', () {
      expect(placeResultIcon('bus_stop'), PhosphorIconsRegular.bus);
      expect(placeResultIcon('bus_station'), PhosphorIconsRegular.bus);
      expect(placeResultIcon('subway'), PhosphorIconsRegular.subway);
      expect(placeResultIcon('subway_entrance'), PhosphorIconsRegular.subway);
      expect(placeResultIcon('train'), PhosphorIconsRegular.train);
      expect(placeResultIcon('train_station'), PhosphorIconsRegular.train);
      expect(placeResultIcon('halt'), PhosphorIconsRegular.train);
      expect(placeResultIcon('platform'), PhosphorIconsRegular.train);
      expect(placeResultIcon('tram_stop'), PhosphorIconsRegular.tram);
      expect(placeResultIcon('ferry_terminal'), PhosphorIconsRegular.boat);
      expect(placeResultIcon('aerodrome'), PhosphorIconsRegular.airplane);
      expect(placeResultIcon('taxi'), PhosphorIconsRegular.taxi);
      expect(placeResultIcon('bicycle_rental'), PhosphorIconsRegular.bicycle);
    });

    test('reads a compound category by its first recognised token', () {
      // Not a "station" — the gas token wins.
      expect(placeResultIcon('gas_station'), PhosphorIconsRegular.gasPump);
      expect(placeResultIcon('fuel'), PhosphorIconsRegular.gasPump);
      expect(
        placeResultIcon('charging_station'),
        PhosphorIconsRegular.chargingStation,
      );
      expect(placeResultIcon('coffee_shop'), PhosphorIconsRegular.coffee);
      expect(placeResultIcon('fast_food'), PhosphorIconsRegular.forkKnife);
      expect(placeResultIcon('place_of_worship'), PhosphorIconsRegular.church);
      expect(placeResultIcon('drinking_water'), PhosphorIconsRegular.drop);
      expect(placeResultIcon('supermarket'), PhosphorIconsRegular.shoppingCart);
      expect(placeResultIcon('hotel'), PhosphorIconsRegular.bed);
    });

    test('is case- and separator-insensitive', () {
      expect(placeResultIcon('Bus Stop'), PhosphorIconsRegular.bus);
      expect(placeResultIcon('TRAIN-STATION'), PhosphorIconsRegular.train);
      expect(placeResultIcon('  Cafe  '), PhosphorIconsRegular.coffee);
      expect(placeResultIcon('Coffee'), PhosphorIconsRegular.coffee);
    });

    test('falls back to the pin for ordinary results and unknowns', () {
      for (final String category in <String>[
        '',
        'address',
        'house',
        'house_number',
        'road',
        'street',
        'residential',
        'city',
        'town',
        'village',
        'suburb',
        'country',
        'region',
        'neighbourhood',
        'postcode',
        'building',
        'water',
        'something_unknown',
      ]) {
        expect(
          placeResultIcon(category),
          PhosphorIconsRegular.mapPin,
          reason: '"$category" should keep the generic pin',
        );
      }
    });

    test('handles a null category', () {
      expect(placeResultIcon(null), PhosphorIconsRegular.mapPin);
    });
  });
}
