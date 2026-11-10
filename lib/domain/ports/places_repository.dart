import '../entities/place.dart';
import '../entities/recent_search.dart';

/// Local persistence for place details, search history, home/work and
/// bookmarks.
///
/// Implemented over the local [AppDatabase] in `data/local/database/`.
abstract interface class PlacesRepository {
  Future<Place?> placeById(String id);

  Future<List<Place>> bookmarks();

  Future<void> setBookmark(Place place, {required bool bookmarked});

  /// The recent searches (places opened/navigated to and queries submitted),
  /// newest first.
  Future<List<RecentSearch>> recentSearches();

  /// Records [place] at the top of the recent list (de-duplicated by id).
  Future<void> recordRecentPlace(Place place);

  /// Records [query] at the top of the recent list (de-duplicated by text).
  Future<void> recordRecentQuery(String query);

  /// Removes [entry] from the recent list, if present.
  Future<void> removeRecentSearch(RecentSearch entry);

  Future<void> clearRecentSearches();

  /// The place saved as "Home", or `null` when it has not been set.
  Future<Place?> home();

  /// Sets (or, with `null`, removes) the "Home" place.
  Future<void> setHome(Place? place);

  /// The place saved as "Work", or `null` when it has not been set.
  Future<Place?> work();

  /// Sets (or, with `null`, removes) the "Work" place.
  Future<void> setWork(Place? place);
}
