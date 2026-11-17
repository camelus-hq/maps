import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/domain/deep_link.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/state/deep_link.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

void main() {
  const Place osmPlace = Place(
    id: 'way/159230368',
    name: 'The Place',
    position: LatLon(52.5, 13.4),
  );

  ProviderContainer containerWith(FakeOsmPlaceSource osm) {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[osmPlaceSourceProvider.overrideWithValue(osm)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('applying a place link selects the resolved OSM place', () async {
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = containerWith(osm);

    await container
        .read(deepLinkControllerProvider.notifier)
        .apply(const DeepLink.place('way/159230368'));

    expect(container.read(selectedPlaceProvider)?.id, 'way/159230368');
    expect(osm.lookups, contains('way/159230368'));
  });

  test('an unknown place link changes nothing and never throws', () async {
    final ProviderContainer container = containerWith(FakeOsmPlaceSource());

    await container
        .read(deepLinkControllerProvider.notifier)
        .apply(const DeepLink.place('way/404'));

    expect(container.read(selectedPlaceProvider), isNull);
  });

  test('applying a directions link plans mode, origin and stops', () async {
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = containerWith(osm);

    await container
        .read(deepLinkControllerProvider.notifier)
        .apply(
          DeepLink.directions(
            mode: TravelMode.walk,
            origin: const HereEndpoint(),
            stops: const <EndpointRef>[PointEndpoint(LatLon(52.51, 13.41))],
            destination: const OsmEndpoint('way/159230368'),
          ),
        );

    final RouteState route = container.read(routeControllerProvider);
    expect(route.mode, TravelMode.walk);
    expect(route.origin?.id, 'current-location');
    expect(route.destination?.id, 'way/159230368');
    expect(route.stops, hasLength(1));
    expect(route.status, RouteStatus.data);
  });

  test(
    're-applying a place link is a no-op, but re-opens after a clear',
    () async {
      final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
        ..seed('way/159230368', osmPlace);
      final ProviderContainer container = containerWith(osm);
      final DeepLinkController controller = container.read(
        deepLinkControllerProvider.notifier,
      );

      await controller.apply(const DeepLink.place('way/159230368'));
      expect(container.read(selectedPlaceProvider)?.id, 'way/159230368');

      // Same link twice while it is still open: skipped (no thrash).
      await controller.apply(const DeepLink.place('way/159230368'));
      expect(container.read(selectedPlaceProvider)?.id, 'way/159230368');

      // Closed, then the same link again: it must re-open.
      container.read(selectedPlaceProvider.notifier).clear();
      await controller.apply(const DeepLink.place('way/159230368'));
      expect(container.read(selectedPlaceProvider)?.id, 'way/159230368');
    },
  );

  test('a stale re-apply does not overwrite a picked origin', () async {
    const Place willowPark = Place(
      id: 'sample-willow-park',
      name: 'Willow Park',
      position: LatLon(52.515, 13.403),
    );
    final FakeOsmPlaceSource osm = FakeOsmPlaceSource()
      ..seed('way/159230368', osmPlace);
    final ProviderContainer container = containerWith(osm);
    final DeepLinkController controller = container.read(
      deepLinkControllerProvider.notifier,
    );

    const DeepLink link = DeepLink.directions(
      mode: TravelMode.walk,
      origin: HereEndpoint(),
      destination: OsmEndpoint('way/159230368'),
    );
    await controller.apply(link);
    expect(
      container.read(routeControllerProvider).origin?.id,
      'current-location',
    );

    // The traveller picks a different start while the picker is open…
    await container
        .read(routeControllerProvider.notifier)
        .setOrigin(willowPark);
    expect(container.read(routeControllerProvider).origin?.id, willowPark.id);

    // …then the route is re-created and re-applies the stale URL.
    await controller.apply(link);
    expect(container.read(routeControllerProvider).origin?.id, willowPark.id);
  });

  test('applying a view moves the camera', () async {
    final ProviderContainer container = containerWith(FakeOsmPlaceSource());

    await container
        .read(deepLinkControllerProvider.notifier)
        .apply(
          const DeepLink.map(
            view: Camera(target: LatLon(52.4, 13.3), zoom: 14),
          ),
        );

    final Camera camera = container.read(mapServiceProvider).camera;
    expect(camera.target.latitude, closeTo(52.4, 1e-9));
    expect(camera.target.longitude, closeTo(13.3, 1e-9));
    expect(camera.zoom, 14);
  });
}
