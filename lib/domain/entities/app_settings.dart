import 'place_category.dart';
import 'push.dart';

/// User-selectable app settings (our own options; persisted locally).
enum DistanceUnit { metric, imperial }

/// The choices offered for "how many recent trips to keep" (the oldest are
/// dropped automatically once the limit is reached).
const List<int> recentTripsLimits = <int>[10, 20, 50];

/// The default keep-limit when the setting has never been written.
const int defaultRecentTripsLimit = 20;

/// Snaps an arbitrary limit to one of [recentTripsLimits], so a hand-edited
/// store or a renamed value can never leave the setting out of range.
int sanitizeRecentTripsLimit(int? value) {
  for (final int allowed in recentTripsLimits) {
    if (allowed == value) {
      return allowed;
    }
  }
  return defaultRecentTripsLimit;
}

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
/// * [camelus] — the Camelus map services: Photon, Overpass,
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
    this.pushTransport = PushTransport.firebase,
    this.recentTripsLimit = defaultRecentTripsLimit,
  });

  final DistanceUnit unit;
  final AppThemeMode theme;

  /// Developer option: list every OpenStreetMap tag on the place sheet.
  final bool showOsmTags;

  /// The selected search provider.
  final SearchBackend searchBackend;

  /// The category ids pinned to the chip row under the search bar, in order.
  final List<String> pinnedCategoryIds;

  /// How push notifications reach this device (Firebase by default; `off`
  /// disables push).
  final PushTransport pushTransport;

  /// How many recorded trips to keep; the oldest are deleted when the limit is
  /// reached. One of [recentTripsLimits].
  final int recentTripsLimit;

  bool get imperial => unit == DistanceUnit.imperial;

  AppSettings copyWith({
    DistanceUnit? unit,
    AppThemeMode? theme,
    bool? showOsmTags,
    SearchBackend? searchBackend,
    List<String>? pinnedCategoryIds,
    PushTransport? pushTransport,
    int? recentTripsLimit,
  }) => AppSettings(
    unit: unit ?? this.unit,
    theme: theme ?? this.theme,
    showOsmTags: showOsmTags ?? this.showOsmTags,
    searchBackend: searchBackend ?? this.searchBackend,
    pinnedCategoryIds: pinnedCategoryIds ?? this.pinnedCategoryIds,
    pushTransport: pushTransport ?? this.pushTransport,
    recentTripsLimit: recentTripsLimit ?? this.recentTripsLimit,
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.unit == unit &&
      other.theme == theme &&
      other.showOsmTags == showOsmTags &&
      other.searchBackend == searchBackend &&
      other.pushTransport == pushTransport &&
      other.recentTripsLimit == recentTripsLimit &&
      _sameList(other.pinnedCategoryIds, pinnedCategoryIds);

  @override
  int get hashCode => Object.hash(
    unit,
    theme,
    showOsmTags,
    searchBackend,
    pushTransport,
    recentTripsLimit,
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
