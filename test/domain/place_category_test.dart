import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/place_category.dart';

void main() {
  group('placeCategoryForSearch', () {
    test('matches the whole query against ids, labels and synonyms', () {
      expect(placeCategoryForSearch('cafe')?.label, 'Cafes');
      expect(placeCategoryForSearch('cafes')?.label, 'Cafes');
      expect(placeCategoryForSearch('coffee')?.label, 'Cafes');
      expect(placeCategoryForSearch('restaurant')?.label, 'Restaurants');
      expect(placeCategoryForSearch('restaurants')?.label, 'Restaurants');
      expect(placeCategoryForSearch('groceries')?.label, 'Groceries');
      expect(placeCategoryForSearch('hotel')?.label, 'Hotels');
      expect(placeCategoryForSearch('parks')?.label, 'Parks');
      expect(placeCategoryForSearch('park')?.label, 'Parks');
      expect(placeCategoryForSearch('gas')?.label, 'Gas stations');
      expect(placeCategoryForSearch('toilets')?.label, 'Toilets');
      expect(placeCategoryForSearch('water fountain')?.label, 'Water fountain');
      expect(placeCategoryForSearch('drinking_water')?.id, 'drinking_water');
    });

    test('does not swallow a place name', () {
      // A real place called "Harbour Coffee" must stay a text search.
      expect(placeCategoryForSearch('Harbour Coffee'), isNull);
      expect(placeCategoryForSearch('unrelated thing'), isNull);
      expect(placeCategoryForSearch(''), isNull);
      expect(placeCategoryForSearch('   '), isNull);
      expect(placeCategoryForSearch(null), isNull);
    });
  });

  group('placeCategoryFromText', () {
    test('matches provider category strings loosely', () {
      expect(placeCategoryFromText('burger restaurant')?.label, 'Restaurants');
      expect(placeCategoryFromText('food')?.label, 'Restaurants');
      expect(placeCategoryFromText('Coffee shop')?.label, 'Cafes');
      expect(placeCategoryFromText('Cafe')?.label, 'Cafes');
      expect(placeCategoryFromText('Gas')?.label, 'Gas stations');
      expect(placeCategoryFromText('Supermarket')?.label, 'Groceries');
      expect(placeCategoryFromText('Italian restaurant')?.label, 'Restaurants');
      expect(placeCategoryFromText('City Library')?.label, 'Library');
    });

    test('returns null when nothing fits', () {
      expect(placeCategoryFromText('unrelated thing'), isNull);
      expect(placeCategoryFromText(''), isNull);
      expect(placeCategoryFromText(null), isNull);
    });
  });

  group('catalogue', () {
    test('ids are unique and groups are all declared', () {
      final Set<String> ids = <String>{};
      for (final PlaceCategory category in placeCategories) {
        expect(
          ids.add(category.id),
          isTrue,
          reason: 'duplicate id ${category.id}',
        );
        expect(
          categoryGroups,
          contains(category.group),
          reason: '${category.id} has an undeclared group',
        );
      }
    });

    test('the default pins all resolve', () {
      expect(defaultPinnedCategoryIds, hasLength(5));
      expect(
        defaultPinnedCategoryIds.map(
          (String id) => placeCategoryById(id)?.label,
        ),
        <String?>['Parks', 'Cafes', 'Water fountain', 'Groceries', 'Toilets'],
      );
    });

    test('placeCategoryById and ByLabel are case-insensitive', () {
      expect(placeCategoryById('CAFE')?.label, 'Cafes');
      expect(placeCategoryByLabel('cafes')?.id, 'cafe');
      expect(placeCategoryById('nope'), isNull);
      expect(placeCategoryByLabel('nope'), isNull);
      expect(placeCategoryById(null), isNull);
    });

    test('categoriesByIds drops unknown ids and de-duplicates', () {
      final List<PlaceCategory> resolved = categoriesByIds(<String>[
        'cafe',
        'nope',
        'cafe',
        'park',
      ]);
      expect(resolved.map((PlaceCategory c) => c.id), <String>['cafe', 'park']);
    });

    test('the amenity catalogue carries OSM tagging', () {
      expect(placeCategoryById('cafe')?.osmKey, 'amenity');
      expect(placeCategoryById('cafe')?.osmValueList, <String>['cafe']);
      expect(
        placeCategoryById('grocery')?.osmValueList,
        contains('supermarket'),
      );
      expect(placeCategoryById('park')?.osmKey, 'leisure');
      expect(placeCategoryById('park')?.mapboxId, 'park');
      expect(placeCategoryById('drinking_water')?.mapboxId, isNull);
    });
  });
}
