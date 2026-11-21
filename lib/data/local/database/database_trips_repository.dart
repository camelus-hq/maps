import '../../../domain/entities/trip.dart';
import '../../../domain/ports/app_database.dart';
import '../../../domain/ports/trips_repository.dart';
import '../../dto/trip_dto.dart';

/// [TripsRepository] backed by the local [AppDatabase] (ObjectBox on native,
/// drift on the web).
///
/// Every recorded trip lives in one JSON value under the `trips.recent` key, so
/// a new field needs no schema change (the settings store is a generic key/value
/// table). Reads are hostile-safe — a corrupt value reads back as an empty
/// list — and the list is always bounded, so the oldest trips are dropped
/// automatically when the cap is reached.
class DatabaseTripsRepository implements TripsRepository {
  DatabaseTripsRepository({required this.database});

  final AppDatabase database;

  // Database key.
  static const String _key = 'trips.recent';

  /// Hard cap on stored trips, whatever the caller asks for. The settings only
  /// offer 10/20/50; this is the absolute ceiling the store enforces.
  static const int hardMaxTrips = 200;

  @override
  Future<List<Trip>> trips() async => List<Trip>.unmodifiable(
    TripDto.decodeList(await database.readSetting(_key)),
  );

  @override
  Future<void> recordTrip(Trip trip, {required int maxTrips}) async {
    final List<Trip> current = TripDto.decodeList(
      await database.readSetting(_key),
    ).toList();
    current.removeWhere((Trip candidate) => candidate.id == trip.id);
    current.insert(0, trip);
    final int limit = maxTrips.clamp(1, hardMaxTrips);
    if (current.length > limit) {
      current.removeRange(limit, current.length);
    }
    await database.writeSetting(_key, TripDto.encodeList(current));
  }

  @override
  Future<void> deleteTrip(String id) async {
    final List<Trip> current = TripDto.decodeList(
      await database.readSetting(_key),
    ).toList()..removeWhere((Trip trip) => trip.id == id);
    if (current.isEmpty) {
      await database.deleteSetting(_key);
      return;
    }
    await database.writeSetting(_key, TripDto.encodeList(current));
  }

  @override
  Future<void> clearTrips() async {
    await database.deleteSetting(_key);
  }
}
