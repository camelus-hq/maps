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
}
