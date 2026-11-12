import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/transit.dart';

Place _place({
  String? category,
  Map<String, String> tags = const <String, String>{},
}) => Place(
  id: 'node/1',
  name: 'Place',
  position: const LatLon(52.5, 13.4),
  category: category,
  osmTags: tags,
);

void main() {
  test('a Mapbox rail/bus/ferry category is a transit stop', () {
    expect(isTransitStopPlace(_place(category: 'rail')), isTrue);
    expect(isTransitStopPlace(_place(category: 'bus')), isTrue);
    expect(isTransitStopPlace(_place(category: 'ferry')), isTrue);
    expect(isTransitStopPlace(_place(category: 'transit')), isTrue);
    expect(isTransitStopPlace(_place(category: 'stop')), isTrue);
    expect(isTransitStopPlace(_place(category: 'Train Station')), isTrue);
  });

  test('OSM tags mark a stop even without a category', () {
    expect(
      isTransitStopPlace(_place(tags: <String, String>{'railway': 'station'})),
      isTrue,
    );
    expect(
      isTransitStopPlace(_place(tags: <String, String>{'railway': 'halt'})),
      isTrue,
    );
    expect(
      isTransitStopPlace(
        _place(tags: <String, String>{'public_transport': 'stop_position'}),
      ),
      isTrue,
    );
    expect(
      isTransitStopPlace(_place(tags: <String, String>{'highway': 'bus_stop'})),
      isTrue,
    );
    expect(
      isTransitStopPlace(
        _place(tags: <String, String>{'amenity': 'ferry_terminal'}),
      ),
      isTrue,
    );
  });

  test('a shop, restaurant or business is not a stop', () {
    expect(isTransitStopPlace(_place(category: 'restaurant')), isFalse);
    expect(isTransitStopPlace(_place(category: 'business')), isFalse);
    expect(isTransitStopPlace(_place(category: 'cafe')), isFalse);
    expect(isTransitStopPlace(_place()), isFalse);
    expect(
      isTransitStopPlace(_place(tags: <String, String>{'shop': 'bakery'})),
      isFalse,
    );
    // `railway=stop` is a signal, not a passenger stop.
    expect(
      isTransitStopPlace(_place(tags: <String, String>{'railway': 'stop'})),
      isFalse,
    );
  });

  test('the departures query requires a stop id or a coordinate', () {
    expect(const TransitDeparturesQuery().isResolved, isFalse);
    expect(const TransitDeparturesQuery(stopId: '  ').isResolved, isFalse);
    expect(const TransitDeparturesQuery(stopId: 'de:1').isResolved, isTrue);
    expect(
      const TransitDeparturesQuery(position: LatLon(52.5, 13.4)).isResolved,
      isTrue,
    );
  });

  test('isLongDistance flags only the intercity/night/high-speed modes', () {
    expect(TransitMode.highSpeedRail.isLongDistance, isTrue);
    expect(TransitMode.longDistanceRail.isLongDistance, isTrue);
    expect(TransitMode.nightRail.isLongDistance, isTrue);
    expect(TransitMode.regionalRail.isLongDistance, isFalse);
    expect(TransitMode.suburbanRail.isLongDistance, isFalse);
    expect(TransitMode.subway.isLongDistance, isFalse);
    expect(TransitMode.bus.isLongDistance, isFalse);
    expect(TransitMode.coach.isLongDistance, isTrue);
  });

  test(
    'localStopRoutes drops long-distance lines, falling back when alone',
    () {
      const TransitStopRoute ice = TransitStopRoute(
        mode: TransitMode.highSpeedRail,
        routeShortName: 'ICE 10',
      );
      const TransitStopRoute en = TransitStopRoute(
        mode: TransitMode.nightRail,
        routeShortName: 'EN',
      );
      const TransitStopRoute s3 = TransitStopRoute(
        mode: TransitMode.suburbanRail,
        routeShortName: 'S3',
      );
      const TransitStopRoute u8 = TransitStopRoute(
        mode: TransitMode.subway,
        routeShortName: 'U8',
      );

      expect(
        localStopRoutes(<TransitStopRoute>[ice, s3, en, u8])
            .map((TransitStopRoute r) => r.lineLabel)
            .toList(),
        <String>['S3', 'U8'],
      );
      // A long-distance-only station keeps everything.
      expect(localStopRoutes(<TransitStopRoute>[ice, en]).length, 2);
    },
  );
}
