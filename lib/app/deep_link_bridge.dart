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

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/osm_ref.dart';
import '../domain/deep_link.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/place.dart';
import '../state/map_camera.dart';
import '../state/place.dart';
import '../state/ports.dart';
import '../state/route.dart';
import '../state/search.dart';

/// Mirrors the app state out to the router URL (state → URL).
///
/// Whenever the selected place, the route plan, the search query or the camera
/// changes, the URL is rewritten to the canonical [DeepLink] for that state
/// (`/place/way/159230368`, `/directions?mode=…&stop=…`, `/search?q=…`,
/// `?at=52.48,13.36,13z`). Opening or closing a sheet is a `go` (a history
/// entry, so the back gesture closes it again); parameter-only updates use
/// `replace` so typing or panning never floods history.
///
/// The other direction — a URL the user typed, shared or launched into — is
/// matched by go_router and applied by [DeepLinkRouteHost] on each route; this
/// widget never reads the URL. Writes are debounced and only happen when the
/// URL does not already match, so the two halves cannot loop.
class DeepLinkBridge extends ConsumerStatefulWidget {
  const DeepLinkBridge({required this.router, required this.child, super.key});

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<DeepLinkBridge> createState() => _DeepLinkBridgeState();
}

class _DeepLinkBridgeState extends ConsumerState<DeepLinkBridge> {
  /// High enough that typing or panning coalesces into one write, low enough
  /// that a shared URL settles almost immediately.
  static const Duration _debounce = Duration(milliseconds: 350);

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // A route change (returning from a picker, opening a screen) can leave the
    // state ahead of the URL: re-check once it settles. This only ever writes
    // out — incoming URLs are applied by the routes themselves.
    widget.router.routeInformationProvider.addListener(_scheduleOutbound);
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_scheduleOutbound);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<Place?>(selectedPlaceProvider, (Place? _, Place? _) {
      _scheduleOutbound();
    });
    ref.listen<RouteState>(routeControllerProvider, (
      RouteState? _,
      RouteState _,
    ) {
      _scheduleOutbound();
    });
    ref.listen<SearchState>(searchControllerProvider, (
      SearchState? _,
      SearchState _,
    ) {
      _scheduleOutbound();
    });
    ref.listen<AsyncValue<Camera>>(
      mapCameraProvider,
      (AsyncValue<Camera>? _, AsyncValue<Camera> _) => _scheduleOutbound(),
    );
    return widget.child;
  }

  void _scheduleOutbound() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_handleOutbound()));
  }

  Future<void> _handleOutbound() async {
    if (!mounted) {
      return;
    }
    // The route the navigator is actually on: a settings page or a pushed
    // browse keeps its own URL, only the map's own routes are mirrored.
    final Uri current = widget.router.state.uri;
    final DeepLink? link = DeepLink.parse(current);
    if (link == null) {
      return;
    }
    final DeepLink desired = _desired(link);
    if (link.sameAs(desired)) {
      return;
    }
    final String target = desired.toUri().toString();
    if (link.kind == desired.kind) {
      unawaited(widget.router.replace(target));
    } else {
      widget.router.go(target);
    }
  }

  /// The canonical link for the current app state.
  ///
  /// A search stays a search; otherwise the URL mirrors the topmost sheet in
  /// the same priority the map home uses (directions > place > map), so opening
  /// or closing a sheet is reflected no matter which screen triggered it.
  DeepLink _desired(DeepLink current) {
    final Camera camera = ref.read(mapServiceProvider).camera;
    if (current.kind == DeepLinkKind.search) {
      final String query = ref.read(searchControllerProvider).query;
      return DeepLink.search(
        query: query,
        // The view rides along with a real query; an empty search keeps the
        // bare `/search` so merely opening the screen does not rewrite the URL.
        view: query.trim().isEmpty ? null : camera,
      );
    }
    if (ref.read(routeControllerProvider).status != RouteStatus.idle) {
      return _directions();
    }
    final Place? place = ref.read(selectedPlaceProvider);
    if (place != null) {
      // A place sheet fits the camera to itself, so a view would be redundant;
      // leaving it out keeps the place URL stable while the user moves around.
      return DeepLink.place(place.id);
    }
    return DeepLink.map(view: camera);
  }

  DeepLink _directions() {
    final RouteState route = ref.read(routeControllerProvider);
    EndpointRef? refFor(Place? place) {
      if (place == null) {
        return null;
      }
      if (place.id == 'current-location') {
        return const HereEndpoint();
      }
      if (OsmRef.isRef(place.id)) {
        return OsmEndpoint(place.id);
      }
      return PointEndpoint(place.position);
    }

    final List<EndpointRef> stops = <EndpointRef>[];
    for (final Place stop in route.stops) {
      final EndpointRef? ref = refFor(stop);
      if (ref != null) {
        stops.add(ref);
      }
    }
    return DeepLink.directions(
      mode: route.mode,
      origin: refFor(route.origin),
      stops: stops,
      destination: refFor(route.destination),
    );
  }
}
