import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/location.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';

/// A [LocationService] whose fix only arrives when the test completes it,
/// standing in for a permission prompt or a cold GNSS fix.
class _SlowLocationService implements LocationService {
  final Completer<LocationSample?> completer = Completer<LocationSample?>();

  @override
  Future<LocationSample?> lastKnown() => completer.future;

  @override
  Stream<LocationSample> positionStream() =>
      const Stream<LocationSample>.empty();

  @override
  Stream<bool> availabilityStream() => const Stream<bool>.empty();
}

/// A [LocationService] that streams one fix immediately, so the tracker has a
/// position without the (never-answered) `lastKnown` call.
class _StreamingLocationService implements LocationService {
  _StreamingLocationService(this.sample);

  final LocationSample sample;
  final Completer<LocationSample?> lastKnownCompleter =
      Completer<LocationSample?>();

  @override
  Future<LocationSample?> lastKnown() => lastKnownCompleter.future;

  @override
  Stream<LocationSample> positionStream() =>
      Stream<LocationSample>.value(sample);

  @override
  Stream<bool> availabilityStream() => Stream<bool>.value(true);
}

void main() {
  const Place destination = Place(
    id: 'dest',
    name: 'Dest',
    position: LatLon(52.521, 13.4075),
  );

  test('plan() enters the loading state before the location fix arrives', () {
    final _SlowLocationService service = _SlowLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    unawaited(
      container
          .read(routeControllerProvider.notifier)
          .plan(destination, suggestMode: true),
    );

    // Without awaiting the (slow) location lookup, the state must already be
    // loading with the destination set — this is what lets the directions sheet
    // and its shimmer appear on the tap instead of after the fix lands.
    final RouteState state = container.read(routeControllerProvider);
    expect(state.status, RouteStatus.loading);
    expect(state.destination, destination);
  });

  test('plan() uses the tracked fix without calling the location service', () {
    const LocationSample fix = LocationSample(position: LatLon(52.52, 13.405));
    final _StreamingLocationService service = _StreamingLocationService(fix);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[locationServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    // Start the tracker and let its streamed fix land before planning.
    container.read(locationTrackerProvider);
    return pumpEventQueue().then((_) {
      expect(container.read(locationTrackerProvider).hasFix, isTrue);

      unawaited(
        container
            .read(routeControllerProvider.notifier)
            .plan(destination, suggestMode: true),
      );

      // The start (and the distance-suggested mode) are known synchronously,
      // even though `lastKnown` never resolves.
      final RouteState state = container.read(routeControllerProvider);
      expect(state.origin?.position, fix.position);
      expect(state.mode, TravelMode.walk);
    });
  });
}
