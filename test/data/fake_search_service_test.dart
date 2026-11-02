import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/data/fakes/fake_search_service.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/usecases/search_places.dart';

void main() {
  const FakeSearchService service = FakeSearchService();
  const SearchPlaces searchPlaces = SearchPlaces(service);

  group('FakeSearchService', () {
    test('matches by name and category, case-insensitively', () async {
      final List<Place> byName = await service.search('coffee');
      expect(byName, isNotEmpty);
      expect(
        byName.every(
          (Place place) => place.name.toLowerCase().contains('coffee'),
        ),
        isTrue,
      );

      final List<Place> byCategory = await service.search('CAFE');
      expect(byCategory, isNotEmpty);
    });

    test('ignores empty queries', () async {
      expect(await service.search('   '), isEmpty);
    });
  });

  group('SearchPlaces', () {
    test('rejects queries that are too short', () async {
      final Result<List<Place>> result = await searchPlaces('a');
      expect(result.isErr, isTrue);
      expect(result.errorOrNull, isA<ValidationException>());
    });

    test('returns matching places for a valid query', () async {
      final Result<List<Place>> result = await searchPlaces('cafe');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNotEmpty);
    });
  });
}
