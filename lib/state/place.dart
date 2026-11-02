import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/osm_ref.dart';
import '../domain/entities/marker.dart';
import '../domain/entities/place.dart';
import 'ports.dart';

/// Bookmarked (saved) places, re-read from the repository.
final FutureProvider<List<Place>> bookmarksProvider =
    FutureProvider<List<Place>>(
      (Ref ref) => ref.watch(placesRepositoryProvider).bookmarks(),
    );

/// The extra OpenStreetMap details for a place (contact phone/email/website,
/// wheelchair access, opening hours), looked up once per place id.
///
/// `null` when the id is not an OSM element (Mapbox geocoding `poi.…`,
/// synthetic `map:…`), when the element publishes no tags, or when the lookup
/// failed — the sheet then simply shows less, and never blocks on it.
final osmPlaceDetailsProvider = FutureProvider.family<Place?, String>((
  Ref ref,
  String placeId,
) async {
  if (!OsmRef.isRef(placeId)) {
    return null;
  }
  try {
    return await ref.watch(osmPlaceSourceProvider).lookup(placeId);
  } on AppException {
    return null;
  }
});

/// The place currently shown in the details sheet, or `null` when none.
class SelectedPlaceController extends Notifier<Place?> {
  @override
  Place? build() => null;

  void select(Place place) => state = place;

  void clear() => state = null;
}

final NotifierProvider<SelectedPlaceController, Place?> selectedPlaceProvider =
    NotifierProvider<SelectedPlaceController, Place?>(
      SelectedPlaceController.new,
    );

/// Keeps the on-map starred markers in sync with saved places.
///
/// The map home watches this so it is instantiated once and stays alive while
/// the app runs (the search route unmounts the map; [MapService.setSavedMarkers]
/// stashes the markers and replays them on re-attach).
class SavedMarkersController extends Notifier<List<Marker>> {
  @override
  List<Marker> build() {
    ref.listen<AsyncValue<List<Place>>>(
      bookmarksProvider,
      (AsyncValue<List<Place>>? _, AsyncValue<List<Place>> next) =>
          _sync(next.value),
    );
    // Covers bookmarks already resolved when this controller is first built.
    Future<void>.microtask(() => _sync(ref.read(bookmarksProvider).value));
    return const <Marker>[];
  }

  /// Re-reads the saved places and repaints the star markers.
  Future<void> refresh() async {
    ref.invalidate(bookmarksProvider);
    _sync(await ref.read(bookmarksProvider.future));
  }

  void _sync(List<Place>? places) {
    final List<Marker> markers = <Marker>[
      if (places != null)
        for (final Place place in places)
          Marker(id: place.id, position: place.position),
    ];
    state = markers;
    unawaited(ref.read(mapServiceProvider).setSavedMarkers(markers));
  }
}

final NotifierProvider<SavedMarkersController, List<Marker>>
savedMarkersProvider = NotifierProvider<SavedMarkersController, List<Marker>>(
  SavedMarkersController.new,
);
