import 'dart:async';

import 'package:flutter_device_compass/flutter_device_compass.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:openmaps/data/location/geolocator_location_service.dart';

/// Guards the stream lifecycle: toggling follow/navigation must never leave the
/// underlying geolocator or compass subscriptions running (a leak that grows
/// with every toggle).
///
/// The source streams are broadcast controllers so `close()` in teardown
/// completes even when they were never listened to.
void main() {
  test(
    'cancelling the position stream releases the underlying subscriptions',
    () async {
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      final StreamController<CompassEvent> compass =
          StreamController<CompassEvent>.broadcast();
      addTearDown(positions.close);
      addTearDown(compass.close);

      final GeolocatorLocationService service = GeolocatorLocationService(
        permissionCheck: () async => true,
        positionEvents: () => positions.stream,
        compassEvents: compass.stream,
      );

      final StreamSubscription<Object?> subscription = service
          .positionStream()
          .listen((_) {});
      await pumpEventQueue();
      expect(positions.hasListener, isTrue);
      expect(compass.hasListener, isTrue);

      await subscription.cancel();
      await pumpEventQueue();
      expect(positions.hasListener, isFalse);
      expect(compass.hasListener, isFalse);
    },
  );

  test(
    'cancelling before the permission check resolves does not leak',
    () async {
      final StreamController<Position> positions =
          StreamController<Position>.broadcast();
      final StreamController<CompassEvent> compass =
          StreamController<CompassEvent>.broadcast();
      final Completer<bool> permission = Completer<bool>();
      addTearDown(positions.close);
      addTearDown(compass.close);

      final GeolocatorLocationService service = GeolocatorLocationService(
        permissionCheck: () => permission.future,
        positionEvents: () => positions.stream,
        compassEvents: compass.stream,
      );

      final StreamSubscription<Object?> subscription = service
          .positionStream()
          .listen((_) {});
      await subscription.cancel(); // cancel while the check is still pending
      permission.complete(true); // the async start now resumes
      await pumpEventQueue();

      expect(positions.hasListener, isFalse);
      expect(compass.hasListener, isFalse);
    },
  );
}
