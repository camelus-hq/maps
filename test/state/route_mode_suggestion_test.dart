import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/state/route.dart';

/// The distance-based default travel mode when directions are opened fresh.
void main() {
  // The keyless [FakeLocationService] reports SampleData.origin
  // (52.52, 13.405); each destination below is a straight-line hop away.
  const Place near = Place(
    id: 'near',
    name: 'Near',
    position: LatLon(52.525, 13.405), // ~0.6 km
  );
  const Place mid = Place(
    id: 'mid',
    name: 'Mid',
    position: LatLon(52.565, 13.405), // ~5 km
  );
  const Place far = Place(
    id: 'far',
    name: 'Far',
    position: LatLon(52.628, 13.405), // ~12 km
  );
  const Place distant = Place(
    id: 'distant',
    name: 'Distant',
    position: LatLon(52.745, 13.405), // ~25 km
  );

  ProviderContainer container() {
    final ProviderContainer c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test(
    'plan(suggestMode: true) picks the mode for the trip distance',
    () async {
      for (final (Place place, TravelMode expected) in <(Place, TravelMode)>[
        (near, TravelMode.walk),
        (mid, TravelMode.cycle),
        (far, TravelMode.transit),
        (distant, TravelMode.drive),
      ]) {
        final ProviderContainer c = container();
        await c
            .read(routeControllerProvider.notifier)
            .plan(place, suggestMode: true);
        expect(
          c.read(routeControllerProvider).mode,
          expected,
          reason: place.name,
        );
      }
    },
  );

  test('plan() without suggestMode keeps the current mode', () async {
    final ProviderContainer c = container();
    final RouteController controller = c.read(routeControllerProvider.notifier);
    await controller.setMode(TravelMode.drive);

    // A short trip would otherwise default to walking.
    await controller.plan(near);

    expect(c.read(routeControllerProvider).mode, TravelMode.drive);
  });
}
