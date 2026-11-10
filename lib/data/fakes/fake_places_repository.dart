import '../../domain/entities/place.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/ports/places_repository.dart';
import 'sample_data.dart';

/// In-memory [PlacesRepository] for tests and keyless runs.
class FakePlacesRepository implements PlacesRepository {
  static const int _maxRecent = 20;

  final Map<String, Place> _bookmarked = <String, Place>{};
  final List<RecentSearch> _recent = <RecentSearch>[];
  Place? _home;
  Place? _work;

  @override
  Future<Place?> placeById(String id) async {
    for (final Place place in SampleData.places) {
      if (place.id == id) {
        return place;
      }
    }
    final Place? bookmark = _bookmarked[id];
    if (bookmark != null) {
      return bookmark;
    }
    if (_home?.id == id) {
      return _home;
    }
    if (_work?.id == id) {
      return _work;
    }
    return null;
  }

  @override
  Future<List<Place>> bookmarks() async =>
      List<Place>.unmodifiable(_bookmarked.values);

  @override
  Future<void> setBookmark(Place place, {required bool bookmarked}) async {
    if (bookmarked) {
      _bookmarked[place.id] = place;
    } else {
      _bookmarked.remove(place.id);
    }
  }

  @override
  Future<List<RecentSearch>> recentSearches() async =>
      List<RecentSearch>.unmodifiable(_recent);

  @override
  Future<void> recordRecentPlace(Place place) =>
      _record(RecentPlaceSearch(place));

  @override
  Future<void> recordRecentQuery(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await _record(RecentTextSearch(trimmed));
  }

  Future<void> _record(RecentSearch entry) async {
    _recent.removeWhere((RecentSearch candidate) => candidate.key == entry.key);
    _recent.insert(0, entry);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
  }

  @override
  Future<void> clearRecentSearches() async => _recent.clear();

  @override
  Future<void> removeRecentSearch(RecentSearch entry) async {
    _recent.removeWhere((RecentSearch candidate) => candidate.key == entry.key);
  }

  @override
  Future<Place?> home() async => _home;

  @override
  Future<void> setHome(Place? place) async => _home = place;

  @override
  Future<Place?> work() async => _work;

  @override
  Future<void> setWork(Place? place) async => _work = place;
}
