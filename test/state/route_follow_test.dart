import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/state/follow.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

void main() {
  test('planning a route stops follow and fits the route overview', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(followModeProvider.notifier).enable();
    expect(container.read(followModeProvider), isTrue);

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.camera.zoom, 16); // follow zoom

    await container
        .read(routeControllerProvider.notifier)
        .plan(const Place(id: 'd', name: 'Dest', position: LatLon(48.1, 11.6)));

    expect(container.read(followModeProvider), isFalse);
    expect(container.read(routeControllerProvider).status, RouteStatus.data);
    // The route fit (overview) replaced the follow camera.
    expect(map.camera.zoom, lessThan(16));
  });
}
