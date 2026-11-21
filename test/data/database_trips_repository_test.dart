import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/database/database_trips_repository.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';

void main() {
  Trip trip(String id, {int at = 0}) => Trip(
    id: id,
    startedAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: at)),
    endedAt: DateTime.utc(2026, 5, 1).add(Duration(minutes: at + 10)),
    mode: TravelMode.cycle,
    distanceMeters: 1000,
    track: const <LatLon>[LatLon(52.52, 13.40), LatLon(52.53, 13.42)],
  );

  test('recorded trips read back newest-first', () async {
    final repo = DatabaseTripsRepository(database: InMemoryAppDatabase());
    await repo.recordTrip(trip('a'), maxTrips: 10);
    await repo.recordTrip(trip('b'), maxTrips: 10);
    await repo.recordTrip(trip('c'), maxTrips: 10);
    expect((await repo.trips()).map((Trip t) => t.id), <String>['c', 'b', 'a']);
  });

  test('recording the same id replaces rather than duplicates', () async {
    final repo = DatabaseTripsRepository(database: InMemoryAppDatabase());
    await repo.recordTrip(trip('a'), maxTrips: 10);
    await repo.recordTrip(trip('a', at: 5), maxTrips: 10);
    final List<Trip> trips = await repo.trips();
    expect(trips, hasLength(1));
    expect(trips.single.startedAt, DateTime.utc(2026, 5, 1, 0, 5));
  });

  test('the oldest trips are dropped when the limit is reached', () async {
    final repo = DatabaseTripsRepository(database: InMemoryAppDatabase());
    for (int i = 0; i < 12; i++) {
      await repo.recordTrip(trip('t$i', at: i), maxTrips: 5);
    }
    final List<Trip> trips = await repo.trips();
    expect(trips, hasLength(5));
    expect(trips.first.id, 't11');
    expect(trips.last.id, 't7');
  });

  test('deleteTrip and clearTrips remove trips', () async {
    final repo = DatabaseTripsRepository(database: InMemoryAppDatabase());
    await repo.recordTrip(trip('a'), maxTrips: 10);
    await repo.recordTrip(trip('b'), maxTrips: 10);
    await repo.deleteTrip('a');
    expect((await repo.trips()).map((Trip t) => t.id), <String>['b']);
    await repo.clearTrips();
    expect(await repo.trips(), isEmpty);
  });

  test('a corrupt stored value reads back empty, not fatal', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    await db.writeSetting('trips.recent', '{ not json');
    final repo = DatabaseTripsRepository(database: db);
    expect(await repo.trips(), isEmpty);
  });
}
