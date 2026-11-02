import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/osm/nominatim_place_source.dart';
import 'package:openmaps/domain/entities/place.dart';

/// The OSM lookup puts a real name on a place we only know from a review key,
/// so it has to parse Nominatim's `lookup` payload leniently and never throw on
/// hostile input.
void main() {
  NominatimPlaceSource source(
    Future<http.Response> Function(http.Request request) handler, {
    void Function(http.Request request)? onRequest,
  }) {
    return NominatimPlaceSource(
      client: MockClient((http.Request request) {
        onRequest?.call(request);
        return handler(request);
      }),
      baseUrl: 'https://nominatim.test',
    );
  }

  test('parses an element into the real name, address and position', () async {
    late Uri captured;
    final NominatimPlaceSource service = source((http.Request request) async {
      captured = request.url;
      return http.Response(
        '[{"place_id":1,"osm_type":"node","osm_id":2764050762,'
        '"lat":"52.5194096","lon":"13.4119486","category":"shop",'
        '"type":"beauty","name":"BlueBox Sonnenstudio",'
        '"display_name":"BlueBox Sonnenstudio, 7, Grunerstraße, Mitte, '
        'Berlin, 10179, Deutschland","address":{"road":"Grunerstraße",'
        '"house_number":"7"}}]',
        200,
      );
    });

    final Place? place = await service.lookup('node/2764050762');

    expect(place, isNotNull);
    expect(place!.name, 'BlueBox Sonnenstudio');
    expect(place.id, 'node/2764050762');
    expect(place.category, 'beauty');
    expect(place.address, contains('Grunerstraße'));
    expect(place.position.latitude, closeTo(52.5194096, 1e-6));
    expect(place.position.longitude, closeTo(13.4119486, 1e-6));
    // Nominatim's id form for a node.
    expect(captured.queryParameters['osm_ids'], 'N2764050762');
    expect(captured.queryParameters['format'], 'jsonv2');
    // No trailing slash: `/lookup/` 404s on the real service.
    expect(captured.path, '/lookup');
  });

  test('parses contact, accessibility and hours from extratags', () async {
    late Uri captured;
    final NominatimPlaceSource service = source((http.Request request) async {
      captured = request.url;
      return http.Response(
        '[{"lat":"52.5","lon":"13.4","name":"Mokalola",'
        '"display_name":"Mokalola, Berlin","extratags":{'
        '"contact:phone":"030 53166994","contact:email":"hi@mokalola.de",'
        '"contact:website":"instagram.com/mokalola","wheelchair":"yes",'
        '"opening_hours":"Mo-Fr 08:00-18:00"}}]',
        200,
      );
    });

    final Place? place = await service.lookup('node/1');

    expect(place!.phone, '030 53166994');
    expect(place.email, 'hi@mokalola.de');
    expect(place.website, 'instagram.com/mokalola');
    expect(place.wheelchairAccessible, isTrue);
    expect(place.openingHours, 'Mo-Fr 08:00-18:00');
    expect(captured.queryParameters['extratags'], '1');
  });

  test('falls back to the plain OSM keys when contact:* is missing', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"Bar","extratags":{'
        '"phone":"123","mobile":"456","email":"a@b.co","website":"bar.example",'
        '"wheelchair":"no"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/9');
    expect(place!.phone, '123');
    expect(place.email, 'a@b.co');
    expect(place.website, 'bar.example');
    expect(place.wheelchairAccessible, isFalse);
  });

  test('an unknown wheelchair value is null, not a guess', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"X","extratags":'
        '{"wheelchair":"limited"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/10');
    expect(place!.wheelchairAccessible, isNull);
  });

  test('ignores hostile extratags without crashing', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"X","extratags":{'
        '"contact:phone":42,"contact:email":["x","y"],"wheelchair":true}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/11');
    expect(place, isNotNull);
    expect(place!.phone, isNull);
    expect(place.email, isNull);
    expect(place.wheelchairAccessible, isNull);
  });

  test('bounds an oversized contact value', () async {
    final String long = 'a' * 500;
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"X","extratags":'
        '{"contact:phone":"$long"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/12');
    expect(place!.phone, hasLength(40));
  });

  test('maps way and relation references to W/R', () async {
    final List<String> ids = <String>[];
    final NominatimPlaceSource service = source((http.Request request) async {
      ids.add(request.url.queryParameters['osm_ids']!);
      return http.Response('[]', 200);
    });
    await service.lookup('way/123456');
    await service.lookup('relation/99');
    expect(ids, <String>['W123456', 'R99']);
  });

  test('captures every extratags entry as raw OSM tags', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"Bar","extratags":{'
        '"payment:lightning":"yes","takeaway":"only",'
        '"image":"https://example.org/bar.jpg",'
        '"wheelchair:description":"step at the door",'
        '"description:payment":"Cards only over 5 EUR"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/20');
    expect(place, isNotNull);
    expect(place!.osmTags['payment:lightning'], 'yes');
    expect(place.takeaway, 'only');
    expect(place.imageUrls, <String>['https://example.org/bar.jpg']);
    expect(place.wheelchairDescription, 'step at the door');
    expect(place.paymentDescription, 'Cards only over 5 EUR');
    expect(place.paymentMethods.single.suffix, 'lightning');
  });

  test('drops hostile extratags entries but keeps the good ones', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","name":"X","extratags":{'
        '"payment:cash":"yes","bad":["a"],"count":7,"takeaway":"yes"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/21');
    expect(place!.osmTags['payment:cash'], 'yes');
    expect(place.osmTags['takeaway'], 'yes');
    expect(place.osmTags.containsKey('bad'), isFalse);
    expect(place.osmTags.containsKey('count'), isFalse);
  });

  test('bounds the raw tag map and its values', () async {
    final String long = 'v' * 999;
    final Map<String, String> tags = <String, String>{
      'payment:cash': long,
      for (int i = 0; i < 200; i++) 'tag:$i': 'x',
    };
    final String json =
        '[{"lat":"1","lon":"2","name":"X","extratags":'
        '{${tags.entries.map((MapEntry<String, String> e) => '"${e.key}":"${e.value}"').join(',')}}}]';
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(json, 200),
    );
    final Place? place = await service.lookup('node/22');
    expect(place, isNotNull);
    expect(place!.osmTags, hasLength(100));
    expect(place.osmTags['payment:cash'], hasLength(500));
  });

  test('falls back to the display name when there is no name tag', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","display_name":"Some Park, Berlin"}]',
        200,
      ),
    );
    final Place? place = await service.lookup('way/1');
    expect(place!.name, 'Some Park');
    expect(place.category, isNull);
  });

  test('falls back to the street when nothing else is there', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"1","lon":"2","address":{"road":"Grunerstraße",'
        '"house_number":"7"}}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/1');
    expect(place!.name, '7 Grunerstraße');
  });

  test('a miss is null, not an error', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response('[]', 200),
    );
    expect(await service.lookup('node/1'), isNull);
    // An error object (not a list) is also a miss.
    expect(await service.lookup('node/2'), isNull);
  });

  test('caches a lookup (a miss included)', () async {
    int calls = 0;
    final NominatimPlaceSource service = source((http.Request _) async {
      calls++;
      return http.Response('[]', 200);
    });
    await service.lookup('node/1');
    await service.lookup('node/1');
    expect(calls, 1);
  });

  test('rejects references that are not OSM elements', () async {
    final NominatimPlaceSource service = source((http.Request _) async {
      fail('must not call the network for a non-OSM reference');
    });
    expect(await service.lookup('poi.123'), isNull);
    expect(await service.lookup('27640507620'), isNull);
    expect(await service.lookup(''), isNull);
  });

  test('hostile and failed responses are typed errors', () async {
    final NominatimPlaceSource broken = source(
      (http.Request _) async => http.Response('not json at all', 200),
    );
    await expectLater(
      broken.lookup('node/1'),
      throwsA(isA<ValidationException>()),
    );

    final NominatimPlaceSource failing = source(
      (http.Request _) async => http.Response('nope', 500),
    );
    await expectLater(
      failing.lookup('node/2'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a malformed entry is skipped, a good one still wins', () async {
    final NominatimPlaceSource service = source(
      (http.Request _) async => http.Response(
        '[{"lat":"not a number","lon":"2"},'
        '{"lat":"52.5","lon":"13.4","name":"Good"}]',
        200,
      ),
    );
    final Place? place = await service.lookup('node/1');
    expect(place, isNotNull);
    expect(place!.name, 'Good');
  });

  test('sends a descriptive User-Agent', () async {
    String? userAgent;
    final NominatimPlaceSource service = source((http.Request request) async {
      userAgent = request.headers['User-Agent'];
      return http.Response('[]', 200);
    });
    await service.lookup('node/1');
    expect(userAgent, NominatimPlaceSource.userAgent);
    expect(userAgent, contains('OpenMaps'));
  });
}
