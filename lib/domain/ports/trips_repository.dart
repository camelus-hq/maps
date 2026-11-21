import '../entities/trip.dart';

/// Local persistence for recorded trips — the breadcrumb paths travelled during
/// guidance, newest first.
///
/// Implemented over the local `AppDatabase` in `data/local/database/`. Local
/// only: a trip never leaves the device unless the user exports it as GPX.
abstract interface class TripsRepository {
  /// Every stored trip, newest first.
  Future<List<Trip>> trips();

  /// Records [trip] at the top of the list and drops the oldest entries so at
  /// most [maxTrips] are kept. De-duplicated by [Trip.id].
  Future<void> recordTrip(Trip trip, {required int maxTrips});

  /// Removes the trip with [id], if present.
  Future<void> deleteTrip(String id);

  /// Removes every stored trip.
  Future<void> clearTrips();
}
