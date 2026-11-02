import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/place_category.dart';
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

    test('maps the browse-category facilities to bespoke glyphs', () {
      // Chips and results share this table, so the facilities the picker lists
      // keep a real glyph instead of the generic pin.
      expect(placeResultIcon('telephone'), PhosphorIconsRegular.phone);
      expect(placeResultIcon('recycling'), PhosphorIconsRegular.recycle);
      expect(placeResultIcon('waste_basket'), PhosphorIconsRegular.trash);
      expect(placeResultIcon('waste_disposal'), PhosphorIconsRegular.trash);
      expect(placeResultIcon('bench'), PhosphorIconsRegular.seat);
      expect(placeResultIcon('shelter'), PhosphorIconsRegular.tent);
      expect(placeResultIcon('clock'), PhosphorIconsRegular.clock);
      expect(
        placeResultIcon('vending_machine'),
        PhosphorIconsRegular.storefront,
      );
      expect(placeResultIcon('arts_centre'), PhosphorIconsRegular.palette);
      expect(
        placeResultIcon('community_centre'),
        PhosphorIconsRegular.usersThree,
      );
      expect(placeResultIcon('music_venue'), PhosphorIconsRegular.musicNote);
      expect(placeResultIcon('public_bookcase'), PhosphorIconsRegular.books);
      expect(placeResultIcon('photo_booth'), PhosphorIconsRegular.camera);
    });

    test('every browse category resolves like its provider values', () {
      // One source of truth: the chip for a category (keyed by id) must show the
      // same glyph as the search results it browses (keyed by the OSM value).
      for (final PlaceCategory category in placeCategories) {
        final IconData chip = placeResultIcon(category.id);
        for (final String value in category.osmValueList) {
          expect(
            placeResultIcon(value),
            chip,
            reason: '"${category.id}" chip should match the glyph for "$value"',
          );
        }
      }
    });
  });
}
