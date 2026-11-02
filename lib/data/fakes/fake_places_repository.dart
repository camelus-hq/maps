import '../../domain/entities/place.dart';
import '../../domain/ports/places_repository.dart';
import 'sample_data.dart';

/// In-memory [PlacesRepository]; persistence lands in M3.
class FakePlacesRepository implements PlacesRepository {
  static const int _maxRecent = 10;

  final Map<String, Place> _bookmarked = <String, Place>{};
  final List<String> _recent = <String>[];

  @override
  Future<Place?> placeById(String id) async {
    for (final Place place in SampleData.places) {
      if (place.id == id) {
        return place;
      }
    }
    return _bookmarked[id];
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
  Future<List<String>> recentQueries() async =>
      List<String>.unmodifiable(_recent);

  @override
  Future<void> recordQuery(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _recent.remove(trimmed);
    _recent.insert(0, trimmed);
    if (_recent.length > _maxRecent) {
      _recent.removeRange(_maxRecent, _recent.length);
    }
  }

  @override
  Future<void> clearRecentQueries() async => _recent.clear();
}
