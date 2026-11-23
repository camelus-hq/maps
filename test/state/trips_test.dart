import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';
import 'package:openmaps/state/settings.dart';
import 'package:openmaps/state/trips.dart';

void main() {
  Trip trip(String id, {int at = 0}) => Trip(
    id: id,
    startedAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: at)),
    endedAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: at + 10)),
    mode: TravelMode.cycle,
    distanceMeters: 1000,
    track: const <LatLon>[LatLon(52.52, 13.40), LatLon(52.53, 13.42)],
  );

  test('recording keeps at most the configured number of trips', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RecentTripsController controller = container.read(
      recentTripsProvider.notifier,
    );
    // Flush the initial (empty) load.
    await Future<void>.delayed(Duration.zero);

    final int keep = container.read(settingsProvider).recentTripsLimit;
    for (int i = 0; i < keep + 5; i++) {
      await controller.record(trip('t$i', at: i));
    }

    final List<Trip> trips = container.read(recentTripsProvider);
    expect(trips, hasLength(keep));
    expect(trips.first.id, 't${keep + 4}');
  });

  test('the keep-limit follows the setting', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setRecentTripsLimit(10);
    await Future<void>.delayed(Duration.zero);

    final RecentTripsController controller = container.read(
      recentTripsProvider.notifier,
    );
    for (int i = 0; i < 14; i++) {
      await controller.record(trip('t$i', at: i));
    }
    expect(container.read(recentTripsProvider), hasLength(10));
  });

  test('delete and clear remove trips; byId resolves', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final RecentTripsController controller = container.read(
      recentTripsProvider.notifier,
    );
    await controller.record(trip('a'));
    await controller.record(trip('b'));

    expect(controller.byId('a')?.id, 'a');
    expect(controller.byId('missing'), isNull);

    await controller.delete('a');
    expect(container.read(recentTripsProvider).map((Trip t) => t.id), <String>[
      'b',
    ]);

    await controller.clear();
    expect(container.read(recentTripsProvider), isEmpty);
  });

  test(
    'a zero keep-limit turns recording off but keeps existing trips',
    () async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final RecentTripsController controller = container.read(
        recentTripsProvider.notifier,
      );
      await controller.record(trip('a'));
      expect(container.read(recentTripsProvider), hasLength(1));

      await container.read(settingsProvider.notifier).setRecentTripsLimit(0);
      expect(container.read(settingsProvider).tripRecordingEnabled, isFalse);

      await controller.record(trip('b'));
      // The new trip is dropped; the existing one survives.
      expect(
        container.read(recentTripsProvider).map((Trip t) => t.id),
        <String>['a'],
      );
    },
  );
}
