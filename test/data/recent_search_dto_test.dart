import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/recent_search_dto.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/recent_search.dart';

void main() {
  test('places and queries round-trip through the codec', () {
    const Place place = Place(
      id: 'node/1',
      name: 'Café',
      position: LatLon(52.5, 13.4),
      address: 'Alexanderufer 1',
    );
    final String encoded = RecentSearchDto.encodeList(<RecentSearch>[
      const RecentPlaceSearch(place),
      const RecentTextSearch('coffee'),
    ]);
    final List<RecentSearch> decoded = RecentSearchDto.decodeList(encoded);
    expect(decoded, hasLength(2));
    expect((decoded[0] as RecentPlaceSearch).place, place);
    expect((decoded[1] as RecentTextSearch).text, 'coffee');
  });

  test('hostile / malformed entries are dropped, not thrown', () {
    expect(RecentSearchDto.decodeList(null), isEmpty);
    expect(RecentSearchDto.decodeList(''), isEmpty);
    expect(RecentSearchDto.decodeList('{ not json'), isEmpty);
    expect(RecentSearchDto.decodeList('"a string"'), isEmpty);
    expect(
      RecentSearchDto.decodeList(
        '[{"type":"unknown"},{"type":"query"},{"type":"query","text":42},'
        '{"type":"place","place":{"id":"x"}}]',
      ),
      isEmpty,
    );
  });

  test('a query is trimmed and bounded in length', () {
    final RecentSearch? entry = RecentSearchDto.fromJson(<String, Object?>{
      'type': 'query',
      'text': '  ${'a' * 500}  ',
    });
    expect(entry, isA<RecentTextSearch>());
    expect(
      (entry! as RecentTextSearch).text.length,
      RecentSearchDto.maxQueryLength,
    );
  });
}
