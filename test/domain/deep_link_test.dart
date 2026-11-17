import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/deep_link.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';

void main() {
  const Camera view = Camera(target: LatLon(52.4877824, 13.3660672), zoom: 13);

  group('toUri', () {
    test('map home with a view', () {
      expect(
        const DeepLink.map(view: view).toUri().toString(),
        '/?at=52.4877824,13.3660672,13.0z',
      );
    });

    test('search carries the query and view', () {
      expect(
        const DeepLink.search(query: 'coffee', view: view).toUri().toString(),
        '/search?q=coffee&at=52.4877824,13.3660672,13.0z',
      );
    });

    test('an OSM place uses the type/id path', () {
      expect(
        DeepLink.place('way/159230368', view: view).toUri().toString(),
        '/place/way/159230368?at=52.4877824,13.3660672,13.0z',
      );
    });

    test('a non-OSM place id is a single encoded segment', () {
      expect(DeepLink.place('poi.123').toUri().toString(), '/place/poi.123');
    });

    test('directions carry mode, endpoints and repeated stops', () {
      expect(
        DeepLink.directions(
          mode: TravelMode.drive,
          origin: const HereEndpoint(),
          stops: const <EndpointRef>[
            PointEndpoint(LatLon(52.5, 13.4)),
            OsmEndpoint('node/1'),
          ],
          destination: const OsmEndpoint('way/159230368'),
        ).toUri().toString(),
        '/directions?mode=drive&origin=here&destination=way/159230368'
        '&stop=52.5,13.4&stop=node/1',
      );
    });
  });

  group('parse', () {
    test('round-trips a view (Google-style @… accepted too)', () {
      final DeepLink? link = DeepLink.parse(
        Uri.parse('/?at=@52.4877824,13.3660672,13z'),
      );
      expect(link, isNotNull);
      expect(link!.kind, DeepLinkKind.map);
      expect(link.view!.target.latitude, closeTo(52.4877824, 1e-9));
      expect(link.view!.zoom, 13);
    });

    test('parses a place link', () {
      final DeepLink? link = DeepLink.parse(
        Uri.parse('/place/way/159230368?at=52.48,13.36,13z'),
      );
      expect(link!.kind, DeepLinkKind.place);
      expect(link.placeRef, 'way/159230368');
      expect(link.view, isNotNull);
    });

    test('parses directions with a missing mode and hostile stops', () {
      final DeepLink? link = DeepLink.parse(
        Uri.parse(
          '/directions?origin=here&destination=52.5,13.4'
          '&stop=not-a-ref&stop=node/7&stop=900,900',
        ),
      );
      expect(link!.kind, DeepLinkKind.directions);
      expect(link.mode, isNull);
      expect(link.origin, isA<HereEndpoint>());
      expect(link.destination, isA<PointEndpoint>());
      // The two invalid stops are dropped, not thrown on.
      expect(link.stops, hasLength(1));
      expect((link.stops.single as OsmEndpoint).ref, 'node/7');
    });

    test('returns null for routes the app does not mirror', () {
      expect(DeepLink.parse(Uri.parse('/settings')), isNull);
      expect(DeepLink.parse(Uri.parse('/saved')), isNull);
    });

    test('never throws on hostile input', () {
      for (final String raw in <String>[
        '/place/way/',
        '/place//x',
        '/directions?origin=,',
        '/?at=999,999,999z',
        '/?at=',
        '/search?q=%E2%9C%93',
      ]) {
        expect(() => DeepLink.parse(Uri.parse(raw)), returnsNormally);
      }
    });
  });

  group('sameAs', () {
    test('ignores a sub-pixel camera drift', () {
      final DeepLink a = const DeepLink.map(
        view: Camera(target: LatLon(52.4877824, 13.3660672), zoom: 13),
      );
      final DeepLink b = const DeepLink.map(
        view: Camera(target: LatLon(52.48778241, 13.36606725), zoom: 13.02),
      );
      expect(a.sameAs(b), isTrue);
    });

    test('treats a different destination as a change', () {
      final DeepLink a = DeepLink.directions(
        destination: const OsmEndpoint('way/1'),
      );
      final DeepLink b = DeepLink.directions(
        destination: const OsmEndpoint('way/2'),
      );
      expect(a.sameAs(b), isFalse);
    });
  });
}
