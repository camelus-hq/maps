import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/place_dto.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';

void main() {
  test('round-trips a place', () {
    const Place place = Place(
      id: 'p1',
      name: 'Harbour Coffee',
      position: LatLon(52.52, 13.405),
      category: 'Cafe',
      address: '1 Lantern Way',
    );
    final Place? decoded = PlaceDto.fromJson(PlaceDto.toJson(place));
    expect(decoded, place);
  });

  test('round-trips the OSM contact fields', () {
    const Place place = Place(
      id: 'node/2764050762',
      name: 'Mokalola',
      position: LatLon(52.52, 13.405),
      address: 'Leberstraße 21',
      email: 'hi@mokalola.de',
      phone: '030 53166994',
      website: 'instagram.com/mokalola',
      wheelchairAccessible: true,
      openingHours: 'Mo-Fr 08:00-18:00',
    );
    final Place? decoded = PlaceDto.fromJson(PlaceDto.toJson(place));
    expect(decoded, isNotNull);
    expect(decoded!.email, place.email);
    expect(decoded.phone, place.phone);
    expect(decoded.website, place.website);
    expect(decoded.wheelchairAccessible, isTrue);
    expect(decoded.openingHours, place.openingHours);
  });

  test('round-trips the raw OSM tags', () {
    const Place place = Place(
      id: 'node/1',
      name: 'Mokalola',
      position: LatLon(52.52, 13.405),
      osmTags: <String, String>{
        'payment:cash': 'yes',
        'takeaway': 'only',
        'image': 'https://example.org/a.jpg',
      },
    );
    final Place? decoded = PlaceDto.fromJson(PlaceDto.toJson(place));
    expect(decoded, isNotNull);
    expect(decoded!.osmTags, place.osmTags);
    expect(decoded.paymentMethods.single.suffix, 'cash');
  });

  test('bounds and filters hostile persisted tags', () {
    final Place? decoded = PlaceDto.fromJson(<String, Object?>{
      'id': 'a',
      'name': 'b',
      'lat': 1,
      'lon': 2,
      'osmTags': <Object?, Object?>{
        'ok': 'v',
        5: 'non-string key',
        'pile': <String>['x'],
        'long': 'y' * 900,
      },
    });
    expect(decoded, isNotNull);
    expect(decoded!.osmTags['ok'], 'v');
    expect(decoded.osmTags.containsKey('pile'), isFalse);
    expect(decoded.osmTags['long'], hasLength(500));
  });

  test('drops hostile persisted contact values', () {
    final Place? decoded = PlaceDto.fromJson(<String, Object?>{
      'id': 'p1',
      'name': 'X',
      'lat': 1,
      'lon': 2,
      'phone': '  ',
      'website': 42,
      'wheelchair': 'yes',
      'email': 'a' * 500,
    });
    expect(decoded, isNotNull);
    expect(decoded!.phone, isNull);
    expect(decoded.website, isNull);
    expect(decoded.wheelchairAccessible, isNull);
    expect(decoded.email, hasLength(254));
  });

  test('decodes hostile lists without throwing', () {
    for (final String? json in <String?>[
      null,
      '',
      'not json',
      '{}',
      '42',
      '[1,2,3]',
      '[{"id":"a"}]',
      '[{"id":"a","name":"b"}]',
      '[{"id":"a","name":"b","lat":999,"lon":0}]',
    ]) {
      expect(
        () => PlaceDto.decodeList(json),
        returnsNormally,
        reason: 'json: $json',
      );
    }
  });

  test('drops invalid entries but keeps valid ones', () {
    final String json = PlaceDto.encodeList(<Place>[
      const Place(id: 'ok', name: 'Good', position: LatLon(1, 2)),
    ]);
    expect(PlaceDto.decodeList(json), hasLength(1));
    expect(PlaceDto.decodeList('["x", 5, null]'), isEmpty);
  });
}
