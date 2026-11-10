import 'dart:async';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/lat_lon_bounds.dart';
import '../domain/entities/marker.dart';
import '../domain/entities/place.dart';
import '../domain/entities/place_category.dart';
import '../domain/ports/map_service.dart';
import 'follow.dart';
import 'home.dart';
import 'map_camera.dart';
import 'map_viewport.dart';
import 'ports.dart';
import 'saved_places.dart';
import 'usecases.dart';

enum SearchStatus { idle, loading, data, error }

/// Immutable search state surfaced to the search UI.
class SearchState {
  const SearchState({
    this.query = '',
    this.status = SearchStatus.idle,
    this.results = const <Place>[],
    this.error,
    this.lastQuery,
    this.resultsCamera,
  });

  final String query;
  final SearchStatus status;
  final List<Place> results;
  final AppException? error;

  /// The query the current results came from (null when there are none).
  final String? lastQuery;

  /// The camera the results were fitted to; used to detect a later pan.
  final Camera? resultsCamera;

  SearchState copyWith({
    String? query,
    SearchStatus? status,
    List<Place>? results,
    AppException? error,
    bool clearError = false,
    String? lastQuery,
    bool clearResults = false,
    Camera? resultsCamera,
  }) => SearchState(
    query: query ?? this.query,
    status: status ?? this.status,
    results: clearResults ? const <Place>[] : (results ?? this.results),
    error: clearError ? null : (error ?? this.error),
    lastQuery: clearResults ? null : (lastQuery ?? this.lastQuery),
    resultsCamera: clearResults ? null : (resultsCamera ?? this.resultsCamera),
  );
}

/// Drives search-as-you-type (debounced) and records recent queries.
///
/// Stale responses are dropped: a result is applied only if the query still
/// matches the latest input.
class SearchController extends Notifier<SearchState> {
  static const Duration _debounceDelay = Duration(milliseconds: 300);

  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        query: query,
        status: SearchStatus.idle,
        clearResults: true,
        clearError: true,
      );
      return;
    }
    state = state.copyWith(
      query: query,
      status: SearchStatus.loading,
      clearError: true,
    );
    _debounce = Timer(
      _debounceDelay,
      () => unawaited(_run(trimmed, expectedQuery: trimmed)),
    );
  }

  Future<void> submit(String query) async {
    _debounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await ref.read(recentSearchesProvider.notifier).recordQuery(trimmed);
    state = state.copyWith(
      query: query,
      status: SearchStatus.loading,
      clearError: true,
    );
    // A query that *names* a browse category ("cafes", "coffee", "water
    // fountain") browses the category where the *user* is, so every matching
    // place in the area is listed rather than only the name matches. The map
    // stays visible behind the results sheet; the search screen pops back to it.
    final PlaceCategory? category = placeCategoryForSearch(trimmed);
    if (category != null) {
      ref.read(selectedCategoryProvider.notifier).select(category.label);
      await _browse(category, displayQuery: category.label, useViewport: false);
      return;
    }
    await _run(trimmed, expectedQuery: trimmed);
  }

  /// A plain text search that never diverts to a category browse.
  ///
  /// Used when the search screen is picking a place for a saved Home/Work slot:
  /// a query that happens to name a category ("cafes") should still list the
  /// places it matches there, not open the category results.
  Future<void> submitText(String query) async {
    _debounce?.cancel();
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await ref.read(recentSearchesProvider.notifier).recordQuery(trimmed);
    state = state.copyWith(
      query: query,
      status: SearchStatus.loading,
      clearError: true,
    );
    await _run(trimmed, expectedQuery: trimmed);
  }

  /// Browses a category around the user (the chips / `search.category`
  /// command). Uses the POI category index near the user's location, bounded to
  /// the visible map (capped to ~1 km), falling back to a proximity-biased,
  /// equally bounded text search. Does not record a recent search.
  ///
  /// The map stays visible: selecting a category shows the `CategoryResultsSheet`
  /// over the highlighted pins, so it also publishes the category to
  /// [selectedCategoryProvider].
  Future<void> browseCategory(PlaceCategory category) async {
    ref.read(selectedCategoryProvider.notifier).select(category.label);
    // The map is on screen, so browse what the user is actually looking at.
    await _browse(category, displayQuery: category.label, useViewport: true);
  }

  Future<void> _browse(
    PlaceCategory category, {
    required String displayQuery,
    bool useViewport = true,
  }) async {
    _debounce?.cancel();
    state = state.copyWith(
      query: displayQuery,
      status: SearchStatus.loading,
      clearResults: true,
      clearError: true,
    );
    final LatLon? location = await _currentProximity();
    final LatLonBounds? viewport = _viewportBounds();
    // Where to centre the browse: the user's location when we have a fix, else
    // the map viewport (and, browsing from the search screen, the viewport is
    // ignored because a previous text search can have fitted it somewhere
    // unrelated). There is no text-search substitute: a category the provider
    // cannot browse is shown as an error.
    final bool useViewportBounds = useViewport || location == null;
    final LatLonBounds? bounds = useViewportBounds ? viewport : null;
    final LatLon? center = location ?? viewport?.center;
    if (center == null) {
      _fail(
        const ValidationException('Turn on location to browse nearby places.'),
      );
      return;
    }
    final Result<List<Place>> result = await ref.read(browseCategoryProvider)(
      category.id,
      proximity: center,
      bounds: bounds,
    );
    if (displayQuery != state.query.trim()) {
      return;
    }
    result.fold(
      ok: (List<Place> places) =>
          _applyResults(places, expectedQuery: displayQuery),
      err: _fail,
    );
  }

  /// Surfaces a failed browse as an error state — never a silent substitute —
  /// and drops the previous category's pins so stale places do not linger.
  void _fail(AppException error) {
    state = state.copyWith(
      status: SearchStatus.error,
      clearResults: true,
      error: error,
    );
    unawaited(ref.read(mapServiceProvider).setMarkers(const <Marker>[]));
  }

  Future<void> _run(
    String text, {
    required String expectedQuery,
    LatLonBounds? bounds,
  }) async {
    final LatLon? proximity = await _currentProximity();
    final Result<List<Place>> result = await ref.read(searchPlacesProvider)(
      text,
      proximity: proximity,
      bounds: bounds,
    );
    if (expectedQuery != state.query.trim()) {
      return;
    }
    result.fold(
      ok: (List<Place> places) =>
          _applyResults(places, expectedQuery: expectedQuery),
      err: (AppException error) => state = state.copyWith(
        status: SearchStatus.error,
        clearResults: true,
        error: error,
      ),
    );
  }

  void _applyResults(List<Place> places, {required String expectedQuery}) {
    final MapService map = ref.read(mapServiceProvider);
    ref.read(followModeProvider.notifier).disable();
    state = state.copyWith(
      status: SearchStatus.data,
      results: places,
      lastQuery: expectedQuery,
      clearError: true,
    );
    unawaited(
      map.setMarkers(<Marker>[
        for (final Place place in places)
          Marker(id: place.id, position: place.position),
      ]),
    );
    if (places.isNotEmpty) {
      unawaited(
        map
            .fitCoordinates(<LatLon>[
              for (final Place place in places) place.position,
            ])
            .then((_) {
              if (state.lastQuery == expectedQuery) {
                state = state.copyWith(resultsCamera: map.camera);
              }
            }),
      );
    }
  }

  LatLon? _cachedProximity;

  /// The last known position (cached) used to bias results toward the user.
  Future<LatLon?> _currentProximity() async {
    if (_cachedProximity != null) {
      return _cachedProximity;
    }
    try {
      _cachedProximity =
          (await ref.read(locationServiceProvider).lastKnown())?.position;
    } catch (_) {
      _cachedProximity = null;
    }
    return _cachedProximity;
  }

  /// The map viewport as a geographic rectangle, or `null` before the map has
  /// been laid out. A category ("near me") browse keeps its POI query inside
  /// this rectangle so it only ever returns places the user can actually see.
  LatLonBounds? _viewportBounds() {
    final Size? viewport = ref.read(mapViewportProvider);
    if (viewport == null) {
      return null;
    }
    return LatLonBounds.fromCamera(
      ref.read(mapServiceProvider).camera,
      widthPx: viewport.width,
      heightPx: viewport.height,
    );
  }

  /// Browses places around an arbitrary [center] (the place sheet's "Nearby"
  /// action). Uses the canonical category when known, else a text search of the
  /// category label. Like [browseCategory] it does not record a recent search.
  Future<void> browseNear(
    LatLon center, {
    required String label,
    PlaceCategory? category,
    String? text,
  }) async {
    _debounce?.cancel();
    state = state.copyWith(
      query: label,
      status: SearchStatus.loading,
      clearResults: true,
      clearError: true,
    );
    Result<List<Place>> result;
    if (category != null) {
      result = await ref.read(browseCategoryProvider)(
        category.id,
        proximity: center,
      );
    } else {
      result = await ref.read(searchPlacesProvider)(
        (text ?? label).trim(),
        proximity: center,
      );
    }
    if (label != state.query.trim()) {
      return;
    }
    result.fold(
      ok: (List<Place> places) => _applyResults(places, expectedQuery: label),
      err: (AppException error) => state = state.copyWith(
        status: SearchStatus.error,
        clearResults: true,
        error: error,
      ),
    );
  }

  void reset() {
    _debounce?.cancel();
    state = const SearchState();
    // The result pins are drawn by the map, not the state tree, so clearing the
    // state alone would leave them on the map (deselecting a category chip or
    // closing the sheet left the POIs behind). Drop them with the results.
    unawaited(ref.read(mapServiceProvider).setMarkers(const <Marker>[]));
  }
}

final NotifierProvider<SearchController, SearchState> searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);

/// The device's last known position, used to show result distances; null when
/// there is no fix (permission denied / emulator without a location).
final FutureProvider<LatLon?> userLocationProvider = FutureProvider<LatLon?>(
  (Ref ref) async =>
      (await ref.watch(locationServiceProvider).lastKnown())?.position,
);

/// True when search results are shown but the map has been panned away from
/// them — the "Search this area" affordance.
final Provider<bool> searchAreaVisibleProvider = Provider<bool>((Ref ref) {
  final SearchState search = ref.watch(searchControllerProvider);
  final Camera? camera = ref.watch(mapCameraProvider).value;
  final String? query = search.lastQuery;
  final Camera? fitted = search.resultsCamera;
  if (query == null ||
      fitted == null ||
      camera == null ||
      search.results.isEmpty) {
    return false;
  }
  return camera.target.distanceTo(fitted.target) > 500;
});
