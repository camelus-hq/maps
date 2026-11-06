import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/location.dart';
import 'package:openmaps/state/ports.dart';

/// A [LocationService] whose stream a test drives directly.
class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  void fail() => _controller.addError(StateError('gps'));

  Future<void> dispose() => _controller.close();
}

void main() {
  test('seeds the last known fix', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(locationTrackerProvider);
    // The seed runs on a microtask.
    await Future<void>.delayed(Duration.zero);

    final LocationState state = container.read(locationTrackerProvider);
    expect(state.hasFix, isTrue);
    expect(state.lost, isFalse);
    expect(state.fix!.position, const LatLon(52.52, 13.405));
  });

  test(
    'a fix is live; a stale gap marks the signal lost; a fix recovers it',
    () async {
      final _ControllableLocationService location =
          _ControllableLocationService();
      final ProviderContainer container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(location)],
      );
      addTearDown(() async {
        container.dispose();
        await location.dispose();
      });

      final LocationTracker tracker = container.read(
        locationTrackerProvider.notifier,
      );
      location.emit(
        const LocationSample(position: LatLon(52.52, 13.405), bearing: 90),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationTrackerProvider).lost, isFalse);

      // No fix for longer than the stale window → lost, but the fix is kept.
      tracker.checkStale(DateTime.now().add(const Duration(seconds: 9)));
      final LocationState lost = container.read(locationTrackerProvider);
      expect(lost.lost, isTrue);
      expect(lost.streaming, isFalse);
      expect(lost.fix, isNotNull);

      // A fresh fix recovers the signal.
      location.emit(const LocationSample(position: LatLon(52.53, 13.41)));
      await Future<void>.delayed(Duration.zero);
      final LocationState recovered = container.read(locationTrackerProvider);
      expect(recovered.lost, isFalse);
      expect(recovered.streaming, isTrue);
      expect(recovered.fix!.position, const LatLon(52.53, 13.41));
    },
  );

  test('a stream error marks the signal lost but keeps the last fix', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    container.read(locationTrackerProvider);
    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(locationTrackerProvider).lost, isFalse);

    location.fail();
    await Future<void>.delayed(Duration.zero);
    final LocationState state = container.read(locationTrackerProvider);
    expect(state.lost, isTrue);
    expect(state.fix, isNotNull);
  });

  test('no fix within the grace period marks the signal lost', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    final LocationTracker tracker = container.read(
      locationTrackerProvider.notifier,
    );
    // Nothing has arrived yet, but we are still inside the grace period.
    tracker.checkStale();
    expect(container.read(locationTrackerProvider).lost, isFalse);

    tracker.checkStale(DateTime.now().add(const Duration(days: 1)));
    final LocationState state = container.read(locationTrackerProvider);
    expect(state.lost, isTrue);
    expect(state.hasFix, isFalse);
  });

  test('map.myLocation immediately zooms in on the tracked fix', () async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    container.read(locationTrackerProvider);
    await Future<void>.delayed(Duration.zero);

    await container
        .read(commandRegistryProvider)
        .dispatch('map.myLocation', const <String, Object?>{});

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.camera.zoom, 17);
    expect(map.camera.target, const LatLon(52.52, 13.405));
  });
}
