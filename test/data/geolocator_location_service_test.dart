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

  test('availability follows the OS service status and permission', () async {
    final StreamController<ServiceStatus> statuses =
        StreamController<ServiceStatus>.broadcast();
    addTearDown(statuses.close);

    final GeolocatorLocationService service = GeolocatorLocationService(
      permissionCheck: () async => true,
      serviceStatusEvents: () => statuses.stream,
    );

    final List<bool> seen = <bool>[];
    final StreamSubscription<bool> subscription = service
        .availabilityStream()
        .listen(seen.add);
    await pumpEventQueue();
    // Permission granted and services assumed on → available.
    expect(seen, <bool>[true]);

    statuses.add(ServiceStatus.disabled);
    await pumpEventQueue();
    expect(seen.last, isFalse);

    statuses.add(ServiceStatus.enabled);
    await pumpEventQueue();
    expect(seen.last, isTrue);

    await subscription.cancel();
  });

  test('availability is false when permission is not granted', () async {
    final GeolocatorLocationService service = GeolocatorLocationService(
      permissionCheck: () async => false,
      serviceStatusEvents: () => const Stream<ServiceStatus>.empty(),
    );

    final List<bool> seen = <bool>[];
    final StreamSubscription<bool> subscription = service
        .availabilityStream()
        .listen(seen.add);
    await pumpEventQueue();
    expect(seen, <bool>[false]);

    await subscription.cancel();
  });

  test(
    'cancelling availability releases the service status subscription',
    () async {
      final StreamController<ServiceStatus> statuses =
          StreamController<ServiceStatus>.broadcast();
      addTearDown(statuses.close);

      final GeolocatorLocationService service = GeolocatorLocationService(
        permissionCheck: () async => true,
        serviceStatusEvents: () => statuses.stream,
      );

      final StreamSubscription<bool> subscription = service
          .availabilityStream()
          .listen((_) {});
      await pumpEventQueue();
      expect(statuses.hasListener, isTrue);

      await subscription.cancel();
      await pumpEventQueue();
      expect(statuses.hasListener, isFalse);
    },
  );

  test('concurrent callers share one permission request', () async {
    int calls = 0;
    final StreamController<Position> positions =
        StreamController<Position>.broadcast();
    final StreamController<ServiceStatus> statuses =
        StreamController<ServiceStatus>.broadcast();
    addTearDown(positions.close);
    addTearDown(statuses.close);

    final GeolocatorLocationService service = GeolocatorLocationService(
      permissionCheck: () async {
        calls++;
        await Future<void>.delayed(Duration.zero);
        return true;
      },
      positionEvents: () => positions.stream,
      compassEvents: const Stream<CompassEvent>.empty(),
      serviceStatusEvents: () => statuses.stream,
    );

    // Both streams start at once, as they do on the map home mount.
    final StreamSubscription<Object?> positionSub = service
        .positionStream()
        .listen((_) {});
    final StreamSubscription<Object?> availabilitySub = service
        .availabilityStream()
        .listen((_) {});
    await pumpEventQueue();
    expect(calls, 1);

    await positionSub.cancel();
    await availabilitySub.cancel();
  });
}
