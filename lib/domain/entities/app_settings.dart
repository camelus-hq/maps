import 'place_category.dart';

/// User-selectable app settings (our own options; persisted locally).
enum DistanceUnit { metric, imperial }

/// Theme preference, mapped to Flutter's `ThemeMode` in the app layer.
enum AppThemeMode { system, light, dark }

/// Which hosted service powers search and category browse.
///
/// All sit behind the `SearchService` port, so switching changes nothing in
/// the UI or the domain:
/// * [mapbox] — Mapbox Geocoding (autocomplete) + Search Box (POI categories);
///   needs an access token. Its category index only covers a small canonical
///   set, so browsing an amenity it does not index is an error.
/// * [openstreetmap] — Photon (autocomplete/free-text) + Overpass (POIs), both
///   key-less community services over OpenStreetMap data.
/// * [camelus] — the Camelus map services: Photon, Nominatim, Overpass,
///   Valhalla and MOTIS behind one API key. Selecting it also routes
///   directions, transit and place lookups through camelus.app.
enum SearchBackend { mapbox, openstreetmap, camelus }

class AppSettings {
  const AppSettings({
    this.unit = DistanceUnit.metric,
    this.theme = AppThemeMode.system,
    this.showOsmTags = false,
    this.searchBackend = SearchBackend.mapbox,
    this.pinnedCategoryIds = defaultPinnedCategoryIds,
  });

  final DistanceUnit unit;
  final AppThemeMode theme;

  /// Developer option: list every OpenStreetMap tag on the place sheet.
  final bool showOsmTags;

  /// The selected search provider.
  final SearchBackend searchBackend;

  /// The category ids pinned to the chip row under the search bar, in order.
  final List<String> pinnedCategoryIds;

  bool get imperial => unit == DistanceUnit.imperial;

  AppSettings copyWith({
    DistanceUnit? unit,
    AppThemeMode? theme,
    bool? showOsmTags,
    SearchBackend? searchBackend,
    List<String>? pinnedCategoryIds,
  }) => AppSettings(
    unit: unit ?? this.unit,
    theme: theme ?? this.theme,
    showOsmTags: showOsmTags ?? this.showOsmTags,
    searchBackend: searchBackend ?? this.searchBackend,
    pinnedCategoryIds: pinnedCategoryIds ?? this.pinnedCategoryIds,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.unit == unit &&
      other.theme == theme &&
      other.showOsmTags == showOsmTags &&
      other.searchBackend == searchBackend &&
      _sameList(other.pinnedCategoryIds, pinnedCategoryIds);

  @override
  int get hashCode => Object.hash(
    unit,
    theme,
    showOsmTags,
    searchBackend,
    Object.hashAll(pinnedCategoryIds),
  );
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
