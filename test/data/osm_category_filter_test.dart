import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/osm/osm_category_filter.dart';
import 'package:openmaps/domain/entities/place_category.dart';

void main() {
  group('OsmCategoryFilter', () {
    test('single-value categories become an exact tag match', () {
      expect(OsmCategoryFilter.forCategory('cafe'), '"amenity"="cafe"');
      expect(OsmCategoryFilter.forCategory('toilets'), '"amenity"="toilets"');
      expect(OsmCategoryFilter.forCategory('fuel'), '"amenity"="fuel"');
      expect(
        OsmCategoryFilter.forCategory('drinking_water'),
        '"amenity"="drinking_water"',
      );
    });

    test('multi-value categories become a regex match', () {
      expect(
        OsmCategoryFilter.forCategory('park'),
        r'"leisure"~"^(park|garden|nature_reserve)$"',
      );
      expect(
        OsmCategoryFilter.forCategory('grocery'),
        r'"shop"~"^(supermarket|grocery|convenience|greengrocer)$"',
      );
    });

    test('is case-insensitive and trims', () {
      expect(OsmCategoryFilter.forCategory(' CAFE '), '"amenity"="cafe"');
    });

    test('returns null for an unknown id', () {
      expect(OsmCategoryFilter.forCategory('unknown'), isNull);
      expect(OsmCategoryFilter.forCategory(''), isNull);
    });

    test('every catalogue category maps to a filter', () {
      for (final PlaceCategory category in placeCategories) {
        expect(
          OsmCategoryFilter.forCategory(category.id),
          isNotNull,
          reason: category.id,
        );
      }
    });
  });
}
