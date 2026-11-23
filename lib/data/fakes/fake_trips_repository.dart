import '../../domain/entities/trip.dart';
import '../../domain/ports/trips_repository.dart';

/// In-memory [TripsRepository] for tests and keyless runs.
class FakeTripsRepository implements TripsRepository {
  /// Hard cap on stored trips, matching the database adapter.
  static const int hardMaxTrips = 200;

  final List<Trip> _trips = <Trip>[];

  @override
  Future<List<Trip>> trips() async => List<Trip>.unmodifiable(_trips);

  @override
  Future<void> recordTrip(Trip trip, {required int maxTrips}) async {
    // A non-positive limit means recording is off: store nothing (and leave
    // whatever is already there untouched).
    if (maxTrips <= 0) {
      return;
    }
    _trips.removeWhere((Trip candidate) => candidate.id == trip.id);
    _trips.insert(0, trip);
    final int limit = maxTrips.clamp(1, hardMaxTrips);
    if (_trips.length > limit) {
      _trips.removeRange(limit, _trips.length);
    }
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((Trip trip) => trip.id == id);
  }

  @override
  Future<void> clearTrips() async => _trips.clear();
}
