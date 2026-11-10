import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/place.dart';
import '../../../domain/entities/recent_search.dart';
import '../../../domain/ports/app_database.dart';
import '../../../domain/ports/places_repository.dart';
import '../../dto/place_dto.dart';
import '../../dto/recent_search_dto.dart';
import 'app_database_values.dart';

/// [PlacesRepository] backed by the local [AppDatabase] (ObjectBox on native,
/// drift on the web).
///
/// Everything — recent searches, home/work and bookmarks — lives in one store,
/// as JSON values under a handful of keys, so it is local-only and needs no
/// schema change (the settings store is a generic key/value table).
///
/// **Never crash:** reads are hostile-safe (a corrupt value reads back as
/// empty), and the one-time copy of the pre-database `shared_preferences`
/// values swallows a missing/unavailable prefs plugin rather than failing.
class DatabasePlacesRepository implements PlacesRepository {
  DatabasePlacesRepository({required this.database});

  final AppDatabase database;

  // Database keys.
  static const String _recentKey = 'places.recent';
  static const String _bookmarksKey = 'places.bookmarks';
  static const String _homeKey = 'places.home';
  static const String _workKey = 'places.work';
  static const String _migratedKey = 'places.migratedFromPrefs';

  // Legacy `shared_preferences` keys, copied into the database once.
  static const String _legacyRecentKey = 'openmaps.recent_queries';
  static const String _legacyBookmarksKey = 'openmaps.bookmarks';

  static const int _maxRecent = 20;
  static const int _maxBookmarks = 200;

  Future<SharedPreferences>? _prefs;

  Future<SharedPreferences> _instance() =>
      _prefs ??= SharedPreferences.getInstance();

  // ---------------------------------------------------------------------------
  // Bookmarks
  // ---------------------------------------------------------------------------

  @override
  Future<Place?> placeById(String id) async {
    for (final Place place in await bookmarks()) {
      if (place.id == id) {
        return place;
      }
    }
    final Place? home = await this.home();
    if (home?.id == id) {
      return home;
    }
    final Place? work = await this.work();
    if (work?.id == id) {
      return work;
    }
    return null;
  }

  @override
  Future<List<Place>> bookmarks() async {
    await _migrateLegacyOnce();
    return List<Place>.unmodifiable(
      PlaceDto.decodeList(await database.readSetting(_bookmarksKey)),
    );
  }

  @override
  Future<void> setBookmark(Place place, {required bool bookmarked}) async {
    await _migrateLegacyOnce();
    final List<Place> current = PlaceDto.decodeList(
      await database.readSetting(_bookmarksKey),
    ).toList();
    current.removeWhere((Place candidate) => candidate.id == place.id);
    if (bookmarked) {
      current.insert(0, place);
      if (current.length > _maxBookmarks) {
        current.removeRange(_maxBookmarks, current.length);
      }
    }
    await database.writeSetting(_bookmarksKey, PlaceDto.encodeList(current));
  }

  // ---------------------------------------------------------------------------
  // Recent searches
  // ---------------------------------------------------------------------------

  @override
  Future<List<RecentSearch>> recentSearches() async {
    await _migrateLegacyOnce();
    return List<RecentSearch>.unmodifiable(
      RecentSearchDto.decodeList(await database.readSetting(_recentKey)),
    );
  }

  @override
  Future<void> recordRecentPlace(Place place) =>
      _record(RecentPlaceSearch(place));

  @override
  Future<void> recordRecentQuery(String query) => _record(
    RecentTextSearch(
      query.trim().length > RecentSearchDto.maxQueryLength
          ? query.trim().substring(0, RecentSearchDto.maxQueryLength)
          : query.trim(),
    ),
  );

  Future<void> _record(RecentSearch entry) async {
    if (entry.key.isEmpty ||
        (entry is RecentTextSearch && entry.text.isEmpty)) {
      return;
    }
    await _migrateLegacyOnce();
    final List<RecentSearch> current = RecentSearchDto.decodeList(
      await database.readSetting(_recentKey),
    ).toList();
    current.removeWhere((RecentSearch candidate) => candidate.key == entry.key);
    current.insert(0, entry);
    if (current.length > _maxRecent) {
      current.removeRange(_maxRecent, current.length);
    }
    await database.writeSetting(
      _recentKey,
      RecentSearchDto.encodeList(current),
    );
  }

  @override
  Future<void> clearRecentSearches() async {
    await _migrateLegacyOnce();
    await database.deleteSetting(_recentKey);
  }

  @override
  Future<void> removeRecentSearch(RecentSearch entry) async {
    await _migrateLegacyOnce();
    final List<RecentSearch> current =
        RecentSearchDto.decodeList(await database.readSetting(_recentKey))
            .toList()
          ..removeWhere((RecentSearch candidate) => candidate.key == entry.key);
    await database.writeSetting(
      _recentKey,
      RecentSearchDto.encodeList(current),
    );
  }

  // ---------------------------------------------------------------------------
  // Home / Work
  // ---------------------------------------------------------------------------

  @override
  Future<Place?> home() async {
    await _migrateLegacyOnce();
    return _decodePlace(await database.readSetting(_homeKey));
  }

  @override
  Future<void> setHome(Place? place) async {
    await _migrateLegacyOnce();
    if (place == null) {
      await database.deleteSetting(_homeKey);
    } else {
      await database.writeSetting(_homeKey, jsonEncode(PlaceDto.toJson(place)));
    }
  }

  @override
  Future<Place?> work() async {
    await _migrateLegacyOnce();
    return _decodePlace(await database.readSetting(_workKey));
  }

  @override
  Future<void> setWork(Place? place) async {
    await _migrateLegacyOnce();
    if (place == null) {
      await database.deleteSetting(_workKey);
    } else {
      await database.writeSetting(_workKey, jsonEncode(PlaceDto.toJson(place)));
    }
  }

  /// Decodes a single stored place (a JSON object), or `null` when absent or
  /// malformed.
  static Place? _decodePlace(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    return PlaceDto.fromJson(decoded);
  }

  // ---------------------------------------------------------------------------
  // Legacy copy
  // ---------------------------------------------------------------------------

  /// One-time copy of the pre-database (`shared_preferences`) recent searches
  /// and bookmarks into the database. Only fills keys the database does not
  /// already have, so it is harmless if it runs more than once and never
  /// clobbers a newer value.
  Future<void> _migrateLegacyOnce() async {
    if (await database.readBool(_migratedKey) ?? false) {
      return;
    }
    try {
      final SharedPreferences prefs = await _instance();
      if (await database.readSetting(_bookmarksKey) == null) {
        final String? legacy = prefs.getString(_legacyBookmarksKey);
        if (legacy != null && legacy.isNotEmpty) {
          await database.writeSetting(_bookmarksKey, legacy);
        }
      }
      if (await database.readSetting(_recentKey) == null) {
        final List<String>? legacy = prefs.getStringList(_legacyRecentKey);
        if (legacy != null && legacy.isNotEmpty) {
          final List<RecentSearch> entries = <RecentSearch>[
            for (final String query in legacy)
              if (query.trim().isNotEmpty) RecentTextSearch(query.trim()),
          ];
          if (entries.isNotEmpty) {
            await database.writeSetting(
              _recentKey,
              RecentSearchDto.encodeList(entries),
            );
          }
        }
      }
      await database.writeBool(_migratedKey, true);
    } catch (_) {
      // No prefs plugin (tests / a first run) — nothing to migrate. The flag is
      // left unset so a later run can still import once prefs are available.
    }
  }
}
