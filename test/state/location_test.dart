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

/// A [LocationService] whose position and availability streams a test drives.
class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  final StreamController<bool> _availability =
      StreamController<bool>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  @override
  Stream<bool> availabilityStream() => _availability.stream;

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  void setAvailability(bool available) => _availability.add(available);

  void fail() => _controller.addError(StateError('gps'));

  Future<void> dispose() async {
    await _controller.close();
    await _availability.close();
  }
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
    'a fix stays live without further updates (no GPS-lock signal is inferred)',
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

      container.read(locationTrackerProvider);
      location.emit(
        const LocationSample(position: LatLon(52.52, 13.405), bearing: 90),
      );
      await Future<void>.delayed(Duration.zero);

      // A stationary device emits nothing; that must never read as "lost".
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final LocationState state = container.read(locationTrackerProvider);
      expect(state.lost, isFalse);
      expect(state.streaming, isTrue);
      expect(state.fix, isNotNull);
    },
  );

  test(
    'location services off marks the signal lost; recovery clears it',
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

      container.read(locationTrackerProvider);
      location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationTrackerProvider).lost, isFalse);

      // The OS reports location services unavailable → lost, fix kept.
      location.setAvailability(false);
      await Future<void>.delayed(Duration.zero);
      final LocationState lost = container.read(locationTrackerProvider);
      expect(lost.lost, isTrue);
      expect(lost.streaming, isFalse);
      expect(lost.fix, isNotNull);

      // Services come back → the alert clears without waiting for a new fix.
      location.setAvailability(true);
      await Future<void>.delayed(Duration.zero);
      final LocationState recovered = container.read(locationTrackerProvider);
      expect(recovered.lost, isFalse);
      expect(recovered.hasFix, isTrue);
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

  test('unavailable services with no fix ever marks the signal lost', () async {
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
    // Nothing has arrived; the service reports it cannot locate us.
    location.setAvailability(false);
    await Future<void>.delayed(Duration.zero);
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
