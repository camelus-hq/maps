import '../entities/place.dart';

/// Local persistence for place details, search history and bookmarks.
///
/// Implemented over shared_preferences/drift in `data/local/`.
abstract interface class PlacesRepository {
  Future<Place?> placeById(String id);

  Future<List<Place>> bookmarks();

  Future<void> setBookmark(Place place, {required bool bookmarked});

  Future<List<String>> recentQueries();

  Future<void> recordQuery(String query);

  Future<void> clearRecentQueries();
}
