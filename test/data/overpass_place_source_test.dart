import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/osm/overpass_place_source.dart';
import 'package:openmaps/domain/entities/place.dart';

/// The OSM lookup puts a real name on a place we only know from a review key,
/// so it has to parse Overpass' by-id payload leniently and never throw on
/// hostile input.
void main() {
  OverpassPlaceSource source(
    Future<http.Response> Function(http.Request request) handler, {
    void Function(http.Request request)? onRequest,
  }) {
    return OverpassPlaceSource(
      client: MockClient((http.Request request) {
        onRequest?.call(request);
        return handler(request);
      }),
      baseUrl: 'https://overpass.test/api',
    );
  }

  /// An Overpass body with a single `elements` entry.
  String body(List<Object?> elements) =>
      jsonEncode(<String, Object?>{'version': 0.6, 'elements': elements});

  test('parses an element into the real name, address and position', () async {
    late http.Request captured;
    final OverpassPlaceSource service = source((http.Request request) async {
      captured = request;
      return http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 2764050762,
            'lat': 52.5194096,
            'lon': 13.4119486,
            'tags': <String, Object?>{
              'name': 'BlueBox Sonnenstudio',
              'shop': 'beauty',
              'addr:street': 'Grunerstraße',
              'addr:housenumber': '7',
              'addr:postcode': '10179',
              'addr:city': 'Berlin',
            },
          },
        ]),
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
    // The element is fetched by id over the Overpass interpreter.
    expect(captured.method, 'POST');
    expect(captured.url.path, endsWith('/interpreter'));
    final String query = captured.bodyFields['data'] ?? '';
    expect(query, contains('node(2764050762)'));
    expect(query, contains('out center'));
  });

  test(
    'reads the center of a way and fetches the right element type',
    () async {
      final List<String> queries = <String>[];
      final OverpassPlaceSource service = source((http.Request request) async {
        queries.add(request.bodyFields['data'] ?? '');
        return http.Response(
          body(<Object?>[
            <String, Object?>{
              'type': 'way',
              'id': 123456,
              'center': <String, Object?>{'lat': 52.5, 'lon': 13.4},
              'tags': <String, Object?>{'name': 'Park', 'leisure': 'park'},
            },
          ]),
          200,
        );
      });

      final Place? place = await service.lookup('way/123456');
      expect(place!.id, 'way/123456');
      expect(place.position.latitude, 52.5);
      expect(queries.single, contains('way(123456)'));

      await service.lookup('relation/99');
      expect(queries.last, contains('relation(99)'));
    },
  );

  test('parses contact, accessibility and hours from tags', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 1,
            'lat': 52.5,
            'lon': 13.4,
            'tags': <String, Object?>{
              'name': 'Mokalola',
              'contact:phone': '030 53166994',
              'contact:email': 'hi@mokalola.de',
              'contact:website': 'instagram.com/mokalola',
              'wheelchair': 'yes',
              'opening_hours': 'Mo-Fr 08:00-18:00',
            },
          },
        ]),
        200,
      ),
    );

    final Place? place = await service.lookup('node/1');

    expect(place!.phone, '030 53166994');
    expect(place.email, 'hi@mokalola.de');
    expect(place.website, 'instagram.com/mokalola');
    expect(place.wheelchairAccessible, isTrue);
    expect(place.openingHours, 'Mo-Fr 08:00-18:00');
  });

  test('falls back to the plain OSM keys when contact:* is missing', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 9,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{
              'name': 'Bar',
              'phone': '123',
              'mobile': '456',
              'email': 'a@b.co',
              'website': 'bar.example',
              'wheelchair': 'no',
            },
          },
        ]),
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
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 10,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{'name': 'X', 'wheelchair': 'limited'},
          },
        ]),
        200,
      ),
    );
    final Place? place = await service.lookup('node/10');
    expect(place!.wheelchairAccessible, isNull);
  });

  test('ignores hostile tags without crashing', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 11,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{
              'name': 'X',
              'contact:phone': 42,
              'contact:email': <String>['x', 'y'],
              'wheelchair': true,
            },
          },
        ]),
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
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 12,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{'name': 'X', 'contact:phone': long},
          },
        ]),
        200,
      ),
    );
    final Place? place = await service.lookup('node/12');
    expect(place!.phone, hasLength(40));
  });

  test('captures every tag entry as raw OSM tags', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 20,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{
              'name': 'Bar',
              'payment:lightning': 'yes',
              'takeaway': 'only',
              'image': 'https://example.org/bar.jpg',
              'wheelchair:description': 'step at the door',
              'description:payment': 'Cards only over 5 EUR',
            },
          },
        ]),
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

  test('drops hostile tag entries but keeps the good ones', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 21,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{
              'name': 'X',
              'payment:cash': 'yes',
              'bad': <String>['a'],
              'count': 7,
              'takeaway': 'yes',
            },
          },
        ]),
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
    final Map<String, Object?> tags = <String, Object?>{
      'payment:cash': long,
      for (int i = 0; i < 200; i++) 'tag:$i': 'x',
    };
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 22,
            'lat': 1,
            'lon': 2,
            'tags': tags,
          },
        ]),
        200,
      ),
    );
    final Place? place = await service.lookup('node/22');
    expect(place, isNotNull);
    expect(place!.osmTags, hasLength(100));
    expect(place.osmTags['payment:cash'], hasLength(500));
  });

  test('falls back to the street, then the category, when unnamed', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 23,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{
              'addr:street': 'Grunerstraße',
              'addr:housenumber': '7',
            },
          },
          <String, Object?>{
            'type': 'node',
            'id': 24,
            'lat': 1,
            'lon': 2,
            'tags': <String, Object?>{'amenity': 'fuel'},
          },
        ]),
        200,
      ),
    );
    final Place? withStreet = await service.lookup('node/23');
    expect(withStreet!.name, '7 Grunerstraße');
    final Place? withCategory = await service.lookup('node/24');
    expect(withCategory!.name, 'Fuel');
    expect(withCategory.category, 'fuel');
  });

  test('a miss is null, not an error', () async {
    final OverpassPlaceSource empty = source(
      (http.Request _) async => http.Response(body(<Object?>[]), 200),
    );
    expect(await empty.lookup('node/1'), isNull);
    // A body that is not an Overpass object is also a miss.
    final OverpassPlaceSource notAnObject = source(
      (http.Request _) async => http.Response('[]', 200),
    );
    expect(await notAnObject.lookup('node/2'), isNull);
  });

  test('an Overpass error remark is a typed error', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        '{"version":0.6,"remark":"runtime error: Query timed out"}',
        200,
      ),
    );
    await expectLater(
      service.lookup('node/1'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('caches a lookup (a miss included)', () async {
    int calls = 0;
    final OverpassPlaceSource service = source((http.Request _) async {
      calls++;
      return http.Response(body(<Object?>[]), 200);
    });
    await service.lookup('node/1');
    await service.lookup('node/1');
    expect(calls, 1);
  });

  test('rejects references that are not OSM elements', () async {
    final OverpassPlaceSource service = source((http.Request _) async {
      fail('must not call the network for a non-OSM reference');
    });
    expect(await service.lookup('poi.123'), isNull);
    expect(await service.lookup('27640507620'), isNull);
    expect(await service.lookup('node/0'), isNull);
    expect(await service.lookup(''), isNull);
  });

  test('hostile and failed responses are typed errors', () async {
    final OverpassPlaceSource broken = source(
      (http.Request _) async => http.Response('not json at all', 200),
    );
    await expectLater(
      broken.lookup('node/1'),
      throwsA(isA<ValidationException>()),
    );

    final OverpassPlaceSource failing = source(
      (http.Request _) async => http.Response('nope', 500),
    );
    await expectLater(
      failing.lookup('node/2'),
      throwsA(isA<NetworkException>()),
    );
  });

  test('a malformed element for the requested id is a miss', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 1,
            'lat': 'not a number',
            'lon': 2,
            'tags': <String, Object?>{'name': 'Bad'},
          },
        ]),
        200,
      ),
    );
    expect(await service.lookup('node/1'), isNull);
  });

  test('an element for a different id is ignored', () async {
    final OverpassPlaceSource service = source(
      (http.Request _) async => http.Response(
        body(<Object?>[
          <String, Object?>{
            'type': 'node',
            'id': 999,
            'lat': 52.5,
            'lon': 13.4,
            'tags': <String, Object?>{'name': 'Other'},
          },
        ]),
        200,
      ),
    );
    expect(await service.lookup('node/1'), isNull);
  });

  test('sends a descriptive User-Agent', () async {
    String? userAgent;
    final OverpassPlaceSource service = source((http.Request request) async {
      userAgent = request.headers['User-Agent'];
      return http.Response(body(<Object?>[]), 200);
    });
    await service.lookup('node/1');
    expect(userAgent, OverpassPlaceSource.defaultUserAgent);
    expect(userAgent, contains('OpenMaps'));
  });
}
