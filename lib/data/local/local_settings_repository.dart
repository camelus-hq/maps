import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/place_category.dart';
import '../../domain/ports/app_database.dart';
import '../../domain/ports/settings_repository.dart';
import 'database/app_database_values.dart';

/// [SettingsRepository] for real devices.
///
/// The settings that only matter once the database is up — distance unit,
/// developer options, search provider and the pinned category chips — live in
/// the [AppDatabase]. The theme, the onboarding flag and the skipped-update
/// version stay in `shared_preferences`: they are read at startup (the theme
/// before the first frame) and predate the database.
///
/// On the first run after the move off `shared_preferences`, the legacy values
/// are copied into the database once (see [_migrateLegacyPrefsOnce]).
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({required this.database});

  /// The local store for the settings that moved out of `shared_preferences`.
  final AppDatabase database;

  // shared_preferences keys (unchanged by the move to the database).
  static const String _themeKey = 'openmaps.theme';
  static const String _onboardedKey = 'openmaps.onboarded';
  static const String _skippedUpdateKey = 'openmaps.update.skippedVersionCode';

  // Legacy shared_preferences keys, migrated into the database once.
  static const String _legacyUnitKey = 'openmaps.unit';
  static const String _legacyShowOsmTagsKey = 'openmaps.developer.showOsmTags';
  static const String _legacySearchBackendKey = 'openmaps.search.backend';
  static const String _legacyPinnedCategoriesKey =
      'openmaps.search.pinnedCategories';

  // Database keys.
  static const String _unitKey = 'settings.unit';
  static const String _showOsmTagsKey = 'settings.showOsmTags';
  static const String _searchBackendKey = 'settings.searchBackend';
  static const String _pinnedCategoriesKey = 'settings.pinnedCategories';
  static const String _migratedFromPrefsKey = 'settings.migratedFromPrefs';

  Future<SharedPreferences>? _prefs;

  Future<SharedPreferences> _instance() =>
      _prefs ??= SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    await _migrateLegacyPrefsOnce();
    final SharedPreferences prefs = await _instance();
    final DistanceUnit unit = switch (await database.readString(_unitKey)) {
      'imperial' => DistanceUnit.imperial,
      _ => DistanceUnit.metric,
    };
    final AppThemeMode theme = switch (prefs.getString(_themeKey)) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
    // Unknown/absent values (a renamed or removed provider, schema drift) fall
    // back to Mapbox; every current value round-trips by its own name.
    final String? backendName = await database.readString(_searchBackendKey);
    final SearchBackend searchBackend = SearchBackend.values.firstWhere(
      (SearchBackend backend) => backend.name == backendName,
      orElse: () => SearchBackend.mapbox,
    );
    return AppSettings(
      unit: unit,
      theme: theme,
      showOsmTags: await database.readBool(_showOsmTagsKey) ?? false,
      searchBackend: searchBackend,
      pinnedCategoryIds: await _pinnedCategories(),
    );
  }

  /// The pinned chip row: unknown ids are dropped and the list is capped.
  /// Missing entirely → the defaults; a changed catalogue that leaves nothing
  /// resolvable → the defaults (schema-drift tolerance).
  Future<List<String>> _pinnedCategories() async {
    final List<String>? stored = await database.readStringList(
      _pinnedCategoriesKey,
    );
    if (stored == null) {
      return defaultPinnedCategoryIds;
    }
    final List<String> resolved = <String>[];
    for (final String id in stored) {
      final PlaceCategory? category = placeCategoryById(id);
      if (category != null && !resolved.contains(category.id)) {
        resolved.add(category.id);
      }
      if (resolved.length >= maxPinnedCategories) {
        break;
      }
    }
    if (resolved.isEmpty) {
      return defaultPinnedCategoryIds;
    }
    return List<String>.unmodifiable(resolved);
  }

  @override
  Future<void> save(AppSettings settings) async {
    await database.writeString(_unitKey, settings.unit.name);
    await database.writeBool(_showOsmTagsKey, settings.showOsmTags);
    await database.writeString(_searchBackendKey, settings.searchBackend.name);
    await database.writeStringList(
      _pinnedCategoriesKey,
      settings.pinnedCategoryIds,
    );
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_themeKey, settings.theme.name);
  }

  @override
  Future<bool> onboardingSeen() async =>
      (await _instance()).getBool(_onboardedKey) ?? false;

  @override
  Future<void> setOnboardingSeen(bool seen) async =>
      (await _instance()).setBool(_onboardedKey, seen);

  @override
  Future<int?> skippedUpdateVersionCode() async =>
      (await _instance()).getInt(_skippedUpdateKey);

  @override
  Future<void> setSkippedUpdateVersionCode(int? versionCode) async {
    final SharedPreferences prefs = await _instance();
    if (versionCode == null) {
      await prefs.remove(_skippedUpdateKey);
    } else {
      await prefs.setInt(_skippedUpdateKey, versionCode);
    }
  }

  /// One-time copy of the pre-database settings from `shared_preferences` into
  /// the database. Only fills keys the database does not already have, so it is
  /// harmless if it runs more than once and never clobbers a newer value.
  Future<void> _migrateLegacyPrefsOnce() async {
    if (await database.readBool(_migratedFromPrefsKey) ?? false) {
      return;
    }
    final SharedPreferences prefs = await _instance();
    if (await database.readString(_unitKey) == null) {
      final String? legacy = prefs.getString(_legacyUnitKey);
      if (legacy != null) {
        await database.writeString(_unitKey, legacy);
      }
    }
    if (await database.readBool(_showOsmTagsKey) == null) {
      final bool? legacy = prefs.getBool(_legacyShowOsmTagsKey);
      if (legacy != null) {
        await database.writeBool(_showOsmTagsKey, legacy);
      }
    }
    if (await database.readString(_searchBackendKey) == null) {
      final String? legacy = prefs.getString(_legacySearchBackendKey);
      if (legacy != null) {
        await database.writeString(_searchBackendKey, legacy);
      }
    }
    if (await database.readStringList(_pinnedCategoriesKey) == null) {
      final List<String>? legacy = prefs.getStringList(
        _legacyPinnedCategoriesKey,
      );
      if (legacy != null) {
        await database.writeStringList(_pinnedCategoriesKey, legacy);
      }
    }
    await database.writeBool(_migratedFromPrefsKey, true);
  }
}
