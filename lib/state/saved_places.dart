import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/place.dart';
import '../domain/entities/recent_search.dart';
import '../domain/ports/places_repository.dart';
import 'ports.dart';

/// A saved "Home" / "Work" slot.
///
/// The search screen is showing the saved row when [savedPlacePickProvider] is
/// non-null: selecting a result then fills that slot instead of opening the
/// place sheet.
enum SavedPlaceSlot { home, work }

/// The user's saved Home and Work places (either may be unset).
class SavedPlaces {
  const SavedPlaces({this.home, this.work});

  final Place? home;
  final Place? work;

  SavedPlaces copyWith({
    Place? home,
    Place? work,
    bool clearHome = false,
    bool clearWork = false,
  }) => SavedPlaces(
    home: clearHome ? null : (home ?? this.home),
    work: clearWork ? null : (work ?? this.work),
  );
}

/// Loads and edits the saved Home/Work places through the [PlacesRepository].
class SavedPlacesController extends Notifier<SavedPlaces> {
  @override
  SavedPlaces build() {
    unawaited(_load());
    return const SavedPlaces();
  }

  Future<void> _load() async {
    if (!ref.mounted) {
      return;
    }
    final PlacesRepository repo = ref.read(placesRepositoryProvider);
    final Place? home = await repo.home();
    final Place? work = await repo.work();
    if (!ref.mounted) {
      return;
    }
    state = SavedPlaces(home: home, work: work);
  }

  Future<void> setHome(Place? place) async {
    await ref.read(placesRepositoryProvider).setHome(place);
    state = place == null
        ? state.copyWith(clearHome: true)
        : state.copyWith(home: place);
  }

  Future<void> setWork(Place? place) async {
    await ref.read(placesRepositoryProvider).setWork(place);
    state = place == null
        ? state.copyWith(clearWork: true)
        : state.copyWith(work: place);
  }
}

final NotifierProvider<SavedPlacesController, SavedPlaces> savedPlacesProvider =
    NotifierProvider<SavedPlacesController, SavedPlaces>(
      SavedPlacesController.new,
    );

/// The slot the search screen is currently picking a place for, or `null` when
/// it is a normal search. Set by the Home/Work "Add"/edit rows.
class SavedPlacePickController extends Notifier<SavedPlaceSlot?> {
  @override
  SavedPlaceSlot? build() => null;

  void begin(SavedPlaceSlot slot) => state = slot;

  void clear() => state = null;
}

final NotifierProvider<SavedPlacePickController, SavedPlaceSlot?>
savedPlacePickProvider =
    NotifierProvider<SavedPlacePickController, SavedPlaceSlot?>(
      SavedPlacePickController.new,
    );

/// The recent searches (places opened/navigated to and queries submitted),
/// newest first, loaded from the database and kept in sync as entries are
/// recorded or cleared.
class RecentSearchesController extends Notifier<List<RecentSearch>> {
  @override
  List<RecentSearch> build() {
    unawaited(_load());
    return const <RecentSearch>[];
  }

  Future<void> _load() async {
    if (!ref.mounted) {
      return;
    }
    final List<RecentSearch> loaded = await ref
        .read(placesRepositoryProvider)
        .recentSearches();
    if (!ref.mounted) {
      return;
    }
    state = loaded;
  }

  Future<void> recordPlace(Place place) async {
    await ref.read(placesRepositoryProvider).recordRecentPlace(place);
    await _load();
  }

  Future<void> recordQuery(String query) async {
    await ref.read(placesRepositoryProvider).recordRecentQuery(query);
    await _load();
  }

  Future<void> clear() async {
    await ref.read(placesRepositoryProvider).clearRecentSearches();
    state = const <RecentSearch>[];
  }

  /// Removes a single entry (the row's "Remove from recent" action).
  Future<void> remove(RecentSearch entry) async {
    await ref.read(placesRepositoryProvider).removeRecentSearch(entry);
    await _load();
  }
}

final NotifierProvider<RecentSearchesController, List<RecentSearch>>
recentSearchesProvider =
    NotifierProvider<RecentSearchesController, List<RecentSearch>>(
      RecentSearchesController.new,
    );
