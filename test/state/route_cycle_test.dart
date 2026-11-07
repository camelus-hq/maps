import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/routing_service.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

/// Records the cycling options each request carries.
class _RecordingRoutingService implements RoutingService {
  final List<CyclingOptions?> received = <CyclingOptions?>[];

  @override
  Future<List<Route>> route({
    required List<LatLon> waypoints,
    required TravelMode mode,
    CyclingOptions? cycling,
  }) async {
    received.add(cycling);
    return const <Route>[
      Route(
        legs: <Leg>[],
        distanceMeters: 1000,
        duration: Duration(minutes: 5),
        geometry: <LatLon>[LatLon(52.5, 13.4), LatLon(52.51, 13.41)],
      ),
    ];
  }
}

void main() {
  const Place destination = Place(
    id: 'cycle-destination',
    name: 'Teufelsberg',
    position: LatLon(52.4975, 13.2417),
  );

  ProviderContainer containerWith(_RecordingRoutingService service) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[routingServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a cycle route is planned with the current options', () async {
    final _RecordingRoutingService service = _RecordingRoutingService();
    final ProviderContainer container = containerWith(service);

    await container.read(routeControllerProvider.notifier).plan(destination);

    expect(container.read(routeControllerProvider).mode, TravelMode.cycle);
    expect(service.received.last, CyclingOptions.defaults);
  });

  test('setCyclingOptions stores the options and re-plans', () async {
    final _RecordingRoutingService service = _RecordingRoutingService();
    final ProviderContainer container = containerWith(service);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.plan(destination);
    service.received.clear();

    const CyclingOptions next = CyclingOptions(
      bicycleType: BicycleType.mountain,
      useHills: 0.8,
      avoidEdges: true,
    );
    await controller.setCyclingOptions(next);

    expect(container.read(routeControllerProvider).cycling, next);
    expect(service.received.last, next);
  });

  test('replan:false updates the state without a request', () async {
    final _RecordingRoutingService service = _RecordingRoutingService();
    final ProviderContainer container = containerWith(service);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.plan(destination);
    service.received.clear();

    await controller.setCyclingOptions(
      const CyclingOptions(useRoads: 0.9),
      replan: false,
    );

    expect(container.read(routeControllerProvider).cycling.useRoads, 0.9);
    expect(service.received, isEmpty);
  });

  test('a slider preview then its release re-plans once', () async {
    final _RecordingRoutingService service = _RecordingRoutingService();
    final ProviderContainer container = containerWith(service);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.plan(destination);
    service.received.clear();

    // Drag: preview without a request.
    await controller.setCyclingOptions(
      const CyclingOptions(useHills: 0.6),
      replan: false,
    );
    expect(service.received, isEmpty);

    // Release with the same value still re-plans (the option is dirty).
    await controller.setCyclingOptions(const CyclingOptions(useHills: 0.6));
    expect(service.received, hasLength(1));
    expect(service.received.single?.useHills, 0.6);
  });

  test('walk and drive never forward the cycling options', () async {
    final _RecordingRoutingService service = _RecordingRoutingService();
    final ProviderContainer container = containerWith(service);
    final RouteController controller = container.read(
      routeControllerProvider.notifier,
    );
    await controller.plan(destination);

    await controller.setMode(TravelMode.walk);
    expect(service.received.last, isNull);

    await controller.setMode(TravelMode.drive);
    expect(service.received.last, isNull);
  });
}
