import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/mapbox_map_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/marker.dart';
import 'package:openmaps/domain/entities/route_line.dart';

void main() {
  test('moveCamera before attach is retained and streamed', () async {
    final MapboxMapService service = MapboxMapService(
      accessToken: 'pk.test',
      styleUri: 'mapbox://styles/mapbox/standard',
      initialCamera: const Camera(target: LatLon(0, 0)),
    );

    final List<Camera> events = <Camera>[];
    final StreamSubscription<Camera> subscription = service.cameraStream.listen(
      events.add,
    );

    await service.moveCamera(
      const Camera(target: LatLon(48.1, 11.6), zoom: 15),
    );

    expect(service.camera.target, const LatLon(48.1, 11.6));
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));

    await subscription.cancel();
    service.dispose();
  });

  test('moveCamera de-duplicates unchanged camera emissions', () async {
    final MapboxMapService service = MapboxMapService(
      accessToken: 'pk.test',
      styleUri: 'mapbox://styles/mapbox/standard',
      initialCamera: const Camera(target: LatLon(0, 0)),
    );

    final List<Camera> events = <Camera>[];
    final StreamSubscription<Camera> subscription = service.cameraStream.listen(
      events.add,
    );

    const Camera camera = Camera(target: LatLon(1, 2), zoom: 10);
    await service.moveCamera(camera);
    await service.moveCamera(camera); // identical — suppressed
    await service.moveCamera(camera.copyWith(zoom: 11)); // changed — emitted
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(2));

    await subscription.cancel();
    service.dispose();
  });

  test(
    'map operations are safe while not attached (no channel bridge)',
    () async {
      final MapboxMapService service = MapboxMapService(
        accessToken: 'pk.test',
        styleUri: 'mapbox://styles/mapbox/standard',
        initialCamera: const Camera(target: LatLon(0, 0)),
      );

      // Simulates the map being off-screen (search route): plenty of calls that
      // previously threw a platform channel-error and crashed the app.
      await service.setMarkers(<Marker>[
        const Marker(id: 'a', position: LatLon(1, 2)),
      ]);
      await service.setRouteLines(<RouteLine>[
        const RouteLine(points: <LatLon>[LatLon(1, 2), LatLon(3, 4)]),
      ]);
      await service.fitCoordinates(<LatLon>[const LatLon(1, 2)]);
      await service.moveCamera(const Camera(target: LatLon(5, 6)));
      service.detach();

      expect(service.markers, hasLength(1));
      service.dispose();
    },
  );
}
