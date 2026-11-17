// Copyright (C) 2026 1-leo

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/osm_ref.dart';
import '../domain/deep_link.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/location_sample.dart';
import '../domain/entities/place.dart';
import '../domain/entities/travel_mode.dart';
import '../domain/ports/map_service.dart';
import 'follow.dart';
import 'location.dart';
import 'place.dart';
import 'ports.dart';
import 'route.dart';

/// Applies an incoming deep link (URL → state) — the receiving half of the
/// URL mirror.
///
/// The outbound half (state → URL) lives in `lib/app/deep_link_bridge.dart`,
/// which navigates the router; this controller only ever *reads* a parsed link
/// and mutates the providers the UI already watches, so a deep link runs the
/// same code path as a tap. All external input is hostile: an unknown place or
/// an unresolved endpoint is dropped, never thrown.
class DeepLinkController extends Notifier<DeepLink?> {
  @override
  DeepLink? build() => null;

  /// Applies [link] to the app state, then constrains the map to its view.
  Future<void> apply(DeepLink link) async {
    // A route can be re-created while a screen on top of it closes (a picker
    // over `/directions`), re-applying its now-stale URL. Skip the exact link we
    // already applied **while the state it describes is still in place** — so an
    // edit the picker just made is not reverted, yet closing a sheet and opening
    // it again still re-applies (the state no longer holds it).
    final DeepLink? last = state;
    if (last != null && last.sameAs(link) && _stillApplied(link)) {
      return;
    }
    state = link;
    switch (link.kind) {
      case DeepLinkKind.map:
      case DeepLinkKind.search:
        // The map home and the search screen hold no place/route of their own;
        // the search screen seeds its query from the URL itself.
        break;
      case DeepLinkKind.place:
        await _applyPlace(link.placeRef);
      case DeepLinkKind.directions:
        await _applyDirections(link);
    }
    await _applyView(link.view);
  }

  Future<void> _applyPlace(String? placeRef) async {
    final String placeId = (placeRef ?? '').trim();
    if (placeId.isEmpty || ref.read(selectedPlaceProvider)?.id == placeId) {
      return;
    }
    final Place? place = await _resolve(placeId);
    if (place == null) {
      return; // unknown or unreachable place: leave the map as it is
    }
    ref.read(selectedPlaceProvider.notifier).select(place);
    ref.read(followModeProvider.notifier).disable();
    final MapService map = ref.read(mapServiceProvider);
    await map.moveCamera(map.camera.copyWith(target: place.position, zoom: 15));
  }

  Future<void> _applyDirections(DeepLink link) async {
    final Place? destination = await _resolveEndpoint(link.destination);
    if (destination == null) {
      return; // a destination we cannot place: do not open an empty sheet
    }
    final Place? origin = await _resolveEndpoint(link.origin);
    final List<Place> stops = <Place>[];
    for (final EndpointRef stop in link.stops) {
      final Place? place = await _resolveEndpoint(stop);
      if (place != null) {
        stops.add(place);
      }
    }
    final RouteState current = ref.read(routeControllerProvider);
    final TravelMode mode = link.mode ?? current.mode;
    if (current.status != RouteStatus.idle &&
        _samePlace(current.destination, destination) &&
        _samePlace(current.origin, origin) &&
        current.mode == mode &&
        _sameStops(current.stops, stops)) {
      return; // already showing exactly this plan
    }
    await ref
        .read(routeControllerProvider.notifier)
        .planRoute(
          origin: origin,
          destination: destination,
          stops: stops,
          mode: mode,
        );
  }

  /// Whether the app state still holds what [link] describes (so re-applying it
  /// would be redundant). `false` means the sheet was closed and this is a fresh
  /// open of the same URL.
  bool _stillApplied(DeepLink link) => switch (link.kind) {
    DeepLinkKind.map || DeepLinkKind.search => false,
    DeepLinkKind.place => ref.read(selectedPlaceProvider) != null,
    DeepLinkKind.directions =>
      ref.read(routeControllerProvider).status != RouteStatus.idle,
  };

  Future<void> _applyView(Camera? view) async {
    if (view == null) {
      return;
    }
    ref.read(followModeProvider.notifier).disable();
    await ref.read(mapServiceProvider).moveCamera(view);
  }

  /// Resolves a place id: an OSM element through the (cached) Overpass lookup,
  /// anything else through the local repository.
  Future<Place?> _resolve(String placeRef) async {
    if (OsmRef.isRef(placeRef)) {
      final Place? osm = await ref.read(
        osmPlaceDetailsProvider(placeRef).future,
      );
      if (osm != null) {
        return osm;
      }
    }
    return ref.read(placesRepositoryProvider).placeById(placeRef);
  }

  Future<Place?> _resolveEndpoint(EndpointRef? endpoint) async {
    switch (endpoint) {
      case null:
        return null;
      case HereEndpoint():
        return _currentLocationPlace();
      case OsmEndpoint(ref: final String ref):
        return _resolve(ref);
      case PointEndpoint(point: final LatLon point):
        return Place(
          id: 'map:${point.latitude},${point.longitude}',
          name: 'Dropped pin',
          position: point,
        );
    }
  }

  Future<Place?> _currentLocationPlace() async {
    final LocationSample? tracked = ref.read(locationTrackerProvider).fix;
    final LocationSample? sample =
        tracked ?? await ref.read(locationServiceProvider).lastKnown();
    if (sample == null) {
      return null;
    }
    return Place(
      id: 'current-location',
      name: 'Your location',
      position: sample.position,
    );
  }

  static bool _sameStops(List<Place> a, List<Place> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!_samePlace(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  /// Whether two endpoints are the same place.
  ///
  /// A non-OSM place loses its id in a URL (it becomes a bare coordinate), so
  /// a round-tripped endpoint is matched by position too — otherwise mirroring
  /// the URL would replace a named destination with a "Dropped pin".
  static bool _samePlace(Place? a, Place? b) {
    if (a == null || b == null) {
      return a == b;
    }
    if (a.id == b.id) {
      return true;
    }
    return (a.position.latitude - b.position.latitude).abs() < 1e-5 &&
        (a.position.longitude - b.position.longitude).abs() < 1e-5;
  }
}

final NotifierProvider<DeepLinkController, DeepLink?>
deepLinkControllerProvider = NotifierProvider<DeepLinkController, DeepLink?>(
  DeepLinkController.new,
);
