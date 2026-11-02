import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/place.dart';
import '../../domain/ports/places_repository.dart';
import '../dto/place_dto.dart';

/// [PlacesRepository] backed by `shared_preferences` (recent searches and
/// bookmarks). Local only — no account, no cloud.
class PrefsPlacesRepository implements PlacesRepository {
  static const String _recentKey = 'openmaps.recent_queries';
  static const String _bookmarksKey = 'openmaps.bookmarks';
  static const int _maxRecent = 10;
  static const int _maxBookmarks = 200;

  Future<SharedPreferences>? _prefs;

  Future<SharedPreferences> _instance() =>
      _prefs ??= SharedPreferences.getInstance();

  @override
  Future<Place?> placeById(String id) async {
    final SharedPreferences prefs = await _instance();
    for (final Place place in PlaceDto.decodeList(
      prefs.getString(_bookmarksKey),
    )) {
      if (place.id == id) {
        return place;
      }
    }
    return null;
  }

  @override
  Future<List<Place>> bookmarks() async {
    final SharedPreferences prefs = await _instance();
    return List<Place>.unmodifiable(
      PlaceDto.decodeList(prefs.getString(_bookmarksKey)),
    );
  }

  @override
  Future<void> setBookmark(Place place, {required bool bookmarked}) async {
    final SharedPreferences prefs = await _instance();
    final List<Place> current = PlaceDto.decodeList(
      prefs.getString(_bookmarksKey),
    ).toList();
    current.removeWhere((Place candidate) => candidate.id == place.id);
    if (bookmarked) {
      current.insert(0, place);
      if (current.length > _maxBookmarks) {
        current.removeRange(_maxBookmarks, current.length);
      }
    }
    await prefs.setString(_bookmarksKey, PlaceDto.encodeList(current));
  }

  @override
  Future<List<String>> recentQueries() async {
    final SharedPreferences prefs = await _instance();
    return List<String>.unmodifiable(
      prefs.getStringList(_recentKey) ?? const <String>[],
    );
  }

  @override
  Future<void> recordQuery(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final SharedPreferences prefs = await _instance();
    final List<String> current = List<String>.of(
      prefs.getStringList(_recentKey) ?? const <String>[],
    );
    current.remove(trimmed);
    current.insert(0, trimmed);
    if (current.length > _maxRecent) {
      current.removeRange(_maxRecent, current.length);
    }
    await prefs.setStringList(_recentKey, current);
  }

  @override
  Future<void> clearRecentQueries() async {
    final SharedPreferences prefs = await _instance();
    await prefs.remove(_recentKey);
  }
}
