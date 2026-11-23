import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';

/// The region the price is rendered in comes from the place, never the reader's
/// locale: the provider's country, else an OSM `addr:country` tag.
void main() {
  const LatLon at = LatLon(52.52, 13.405);

  test('prefers the provider country code, uppercased', () {
    const Place place = Place(
      id: 'a',
      name: 'A',
      position: at,
      countryCode: 'de',
    );
    expect(place.regionCode, 'DE');
  });

  test('falls back to the OSM country tags', () {
    const Place fromAddr = Place(
      id: 'a',
      name: 'A',
      position: at,
      osmTags: <String, String>{'addr:country': 'fr'},
    );
    expect(fromAddr.regionCode, 'FR');

    const Place fromIsIn = Place(
      id: 'b',
      name: 'B',
      position: at,
      osmTags: <String, String>{'is_in:country_code': 'us'},
    );
    expect(fromIsIn.regionCode, 'US');
  });

  test('ignores anything that is not a two-letter code', () {
    const Place named = Place(
      id: 'a',
      name: 'A',
      position: at,
      osmTags: <String, String>{'addr:country': 'Germany'},
    );
    expect(named.regionCode, isNull);

    const Place none = Place(id: 'b', name: 'B', position: at);
    expect(none.regionCode, isNull);
  });

  test('withOsmDetails fills a missing country code', () {
    const Place search = Place(id: 'a', name: 'A', position: at);
    const Place osm = Place(
      id: 'a',
      name: 'A',
      position: at,
      countryCode: 'DE',
    );
    expect(search.withOsmDetails(osm).regionCode, 'DE');
  });
}
