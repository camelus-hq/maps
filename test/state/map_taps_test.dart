import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/marker.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/map_taps.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';

/// A tap on a result marker selects that place while keeping the other pins
/// (the tapped one flagged as selected); a tap on a map POI opens its details
/// without moving the camera.
void main() {
  test('marker and POI taps open the right place', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);

    // Keep the controller subscribed to the map streams.
    final ProviderSubscription<void> watch = container.listen(
      mapTapProvider,
      (_, _) {},
    );
    addTearDown(watch.close);

    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;

    map.emitMarkerTap(first['id']! as String);
    await pumpEventQueue();
    expect(container.read(selectedPlaceProvider)?.id, first['id']);

    // Every result pin stays on the map; only the tapped one is highlighted.
    final List<Marker> markers = map.markers;
    expect(markers, hasLength(results.length));
    expect(markers.where((Marker m) => m.selected), hasLength(1));
    expect(markers.firstWhere((Marker m) => m.selected).id, first['id']);

    const Place poi = Place(
      id: 'map:poi',
      name: 'Map POI',
      position: LatLon(52.5, 13.4),
    );
    map.emitPoiTap(poi);
    await pumpEventQueue();
    expect(container.read(selectedPlaceProvider)?.name, 'Map POI');
  });
}
