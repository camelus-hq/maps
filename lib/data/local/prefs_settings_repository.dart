import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/entities/place_category.dart';
import '../../domain/ports/settings_repository.dart';

/// [SettingsRepository] backed by `shared_preferences`.
class PrefsSettingsRepository implements SettingsRepository {
  static const String _unitKey = 'openmaps.unit';
  static const String _themeKey = 'openmaps.theme';
  static const String _onboardedKey = 'openmaps.onboarded';
  static const String _showOsmTagsKey = 'openmaps.developer.showOsmTags';
  static const String _searchBackendKey = 'openmaps.search.backend';
  static const String _pinnedCategoriesKey = 'openmaps.search.pinnedCategories';
  static const String _skippedUpdateKey = 'openmaps.update.skippedVersionCode';

  Future<SharedPreferences>? _prefs;

  Future<SharedPreferences> _instance() =>
      _prefs ??= SharedPreferences.getInstance();

  @override
  Future<AppSettings> load() async {
    final SharedPreferences prefs = await _instance();
    final DistanceUnit unit = switch (prefs.getString(_unitKey)) {
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
    final SearchBackend searchBackend = SearchBackend.values.firstWhere(
      (SearchBackend backend) =>
          backend.name == prefs.getString(_searchBackendKey),
      orElse: () => SearchBackend.mapbox,
    );
    return AppSettings(
      unit: unit,
      theme: theme,
      showOsmTags: prefs.getBool(_showOsmTagsKey) ?? false,
      searchBackend: searchBackend,
      pinnedCategoryIds: _pinnedCategories(prefs),
    );
  }

  /// The pinned chip row: unknown ids are dropped and the list is capped.
  /// Missing entirely → the defaults; a changed catalogue that leaves nothing
  /// resolvable → the defaults (schema-drift tolerance).
  List<String> _pinnedCategories(SharedPreferences prefs) {
    final List<String>? stored = prefs.getStringList(_pinnedCategoriesKey);
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
    final SharedPreferences prefs = await _instance();
    await prefs.setString(_unitKey, settings.unit.name);
    await prefs.setString(_themeKey, settings.theme.name);
    await prefs.setBool(_showOsmTagsKey, settings.showOsmTags);
    await prefs.setString(_searchBackendKey, settings.searchBackend.name);
    await prefs.setStringList(_pinnedCategoriesKey, settings.pinnedCategoryIds);
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
}
