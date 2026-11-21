import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/result.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/usecases.dart';

void main() {
  Future<Route> route(ProviderContainer container) async {
    final Result<List<Route>> result =
        await container.read(requestRouteProvider)(
          waypoints: <LatLon>[
            const LatLon(52.5200, 13.4050),
            const LatLon(52.5300, 13.4200),
          ],
          mode: TravelMode.cycle,
        );
    return (result.valueOrNull ?? const <Route>[]).first;
  }

  test('arriving records the travelled trip in the store', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(await route(container), mode: TravelMode.cycle);

    NavState state = container.read(navigationControllerProvider);
    for (int i = 0; i < 200 && state.status == NavStatus.navigating; i++) {
      controller.step(meters: 1000);
      state = container.read(navigationControllerProvider);
    }
    expect(state.status, NavStatus.arrived);
    // Let the fire-and-forget record land.
    await Future<void>.delayed(Duration.zero);

    final List<Trip> trips = await container
        .read(tripsRepositoryProvider)
        .trips();
    expect(trips, hasLength(1));
    expect(trips.single.mode, TravelMode.cycle);
    expect(trips.single.track.length, greaterThanOrEqualTo(2));
    expect(trips.single.distanceMeters, greaterThan(0));
  });

  test('stopping early records the trip once, not on the next stop', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(await route(container));
    controller.step(meters: 300);
    controller.stop();
    controller.stop();
    await Future<void>.delayed(Duration.zero);

    final List<Trip> trips = await container
        .read(tripsRepositoryProvider)
        .trips();
    expect(trips, hasLength(1));
  });

  test('a session that never moved records nothing', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    controller.start(await route(container));
    controller.stop();
    await Future<void>.delayed(Duration.zero);

    // The start point alone is a single point, so nothing is stored.
    final List<Trip> trips = await container
        .read(tripsRepositoryProvider)
        .trips();
    expect(trips, isEmpty);
  });

  test('a live fix recorded a trail before stopping stores it', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final NavigationController controller = container.read(
      navigationControllerProvider.notifier,
    );
    final Route planned = await route(container);
    controller.start(planned);
    await controller.handlePosition(
      LocationSample(position: planned.geometry.last),
    );
    // Arrival already recorded the trip; a later stop must not add a second.
    controller.stop();
    await Future<void>.delayed(Duration.zero);

    expect(await container.read(tripsRepositoryProvider).trips(), hasLength(1));
  });
}
