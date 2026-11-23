import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/trip.dart';
import '../domain/ports/trips_repository.dart';
import 'ports.dart';
import 'settings.dart';

/// The recorded trips (newest first), loaded from the [TripsRepository] and kept
/// in sync as guidance sessions end and the user manages the list.
///
/// Recording applies the user's "how many recent trips to keep" setting
/// ([AppSettings.recentTripsLimit]) so the oldest are dropped automatically.
class RecentTripsController extends Notifier<List<Trip>> {
  @override
  List<Trip> build() {
    unawaited(_load());
    return const <Trip>[];
  }

  Future<void> _load() async {
    if (!ref.mounted) {
      return;
    }
    final List<Trip> loaded = await ref.read(tripsRepositoryProvider).trips();
    if (!ref.mounted) {
      return;
    }
    state = loaded;
  }

  /// Records a finished trip at the top of the list, trimming the oldest so at
  /// most the configured number are kept.
  ///
  /// When the keep-limit is `0` (recording off) nothing is stored — the
  /// breadcrumb is dropped rather than saved.
  Future<void> record(Trip trip) async {
    final int limit = ref.read(settingsProvider).recentTripsLimit;
    if (limit <= 0) {
      return;
    }
    await ref.read(tripsRepositoryProvider).recordTrip(trip, maxTrips: limit);
    await _load();
  }

  /// Removes the trip with [id] (the row's delete action).
  Future<void> delete(String id) async {
    await ref.read(tripsRepositoryProvider).deleteTrip(id);
    await _load();
  }

  /// Removes every recorded trip.
  Future<void> clear() async {
    await ref.read(tripsRepositoryProvider).clearTrips();
    state = const <Trip>[];
  }

  /// The trip with [id] from the loaded list, or `null`.
  Trip? byId(String id) {
    for (final Trip trip in state) {
      if (trip.id == id) {
        return trip;
      }
    }
    return null;
  }
}

final NotifierProvider<RecentTripsController, List<Trip>> recentTripsProvider =
    NotifierProvider<RecentTripsController, List<Trip>>(
      RecentTripsController.new,
    );
