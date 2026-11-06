import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/camera.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/follow.dart';
import 'package:openmaps/state/ports.dart';

/// A [LocationService] whose fixes can be pushed from a test.
class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  @override
  Stream<bool> availabilityStream() => const Stream<bool>.empty();

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  test('enabling follow recenters the camera on the last known fix', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final FollowController controller = container.read(
      followModeProvider.notifier,
    );
    await controller.enable();
    expect(container.read(followModeProvider), isTrue);

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.camera.target, const LatLon(52.52, 13.405));

    controller.disable();
    expect(container.read(followModeProvider), isFalse);
  });

  test('north-up stays north through fixes while following', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    container
        .read(mapOrientationProvider.notifier)
        .select(MapOrientation.north);
    location.emit(
      const LocationSample(position: LatLon(52.52, 13.405), bearing: 90),
    );
    await container.read(followModeProvider.notifier).enable();
    await Future<void>.delayed(Duration.zero);
    expect(map.camera.bearing, 0);

    // The user walks on: a new heading must not rotate the north-up map.
    location.emit(
      const LocationSample(position: LatLon(52.53, 13.41), bearing: 120),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      map.camera.bearing,
      0,
      reason: 'a north lock must survive location fixes',
    );
  });

  test('heading mode rotates the camera with the device bearing', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    location.emit(
      const LocationSample(position: LatLon(52.52, 13.405), bearing: 90),
    );
    await container.read(followModeProvider.notifier).enable();
    await Future<void>.delayed(Duration.zero);
    expect(map.camera.bearing, 90);
  });

  test('a user map gesture stops follow so fixes do not recenter', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    await container.read(followModeProvider.notifier).enable();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(followModeProvider), isTrue);

    // The user drags the map: follow must drop immediately.
    map.emitUserGesture();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(followModeProvider), isFalse);

    // The user left the camera somewhere; a new fix must not yank it back.
    await map.moveCamera(const Camera(target: LatLon(48.1, 11.6), zoom: 12));
    location.emit(const LocationSample(position: LatLon(53.0, 14.0)));
    await Future<void>.delayed(Duration.zero);
    expect(map.camera.target, const LatLon(48.1, 11.6));
  });
}
