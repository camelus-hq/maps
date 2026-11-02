import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/location_sample.dart';
import '../domain/ports/map_service.dart';
import 'ports.dart';

/// How the map is oriented while following the device location.
enum MapOrientation {
  /// The map rotates so the device heading is up (direction-up).
  heading,

  /// The map stays north-up no matter which way the device points.
  north,
}

/// The chosen orientation, kept across fixes and follow toggles.
///
/// A fix only rotates the camera in [MapOrientation.heading]; in
/// [MapOrientation.north] the bearing stays at 0, so orienting the map north
/// sticks even as the user moves.
class MapOrientationController extends Notifier<MapOrientation> {
  @override
  MapOrientation build() => MapOrientation.heading;

  void select(MapOrientation mode) => state = mode;

  void toggle() => state = state == MapOrientation.north
      ? MapOrientation.heading
      : MapOrientation.north;
}

final NotifierProvider<MapOrientationController, MapOrientation>
mapOrientationProvider =
    NotifierProvider<MapOrientationController, MapOrientation>(
      MapOrientationController.new,
    );

/// Whether the camera is following the device location.
///
/// While enabled it subscribes to the [LocationService] stream and recenters
/// the camera on each fix. The user taking over the map with a gesture (drag,
/// pinch, rotate or tilt) turns it off — so a pan isn't undone by the next fix
/// — and the controls show the difference between "locked on" and "free".
class FollowController extends Notifier<bool> {
  StreamSubscription<LocationSample>? _sub;
  StreamSubscription<void>? _gestureSub;

  @override
  bool build() {
    // A direct map gesture means the user has taken over the camera; drop
    // follow so the map stays where they left it.
    _gestureSub = ref
        .read(mapServiceProvider)
        .userGestureStream
        .listen((_) => disable());
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      unawaited(_gestureSub?.cancel());
    });
    return false;
  }

  Future<void> enable({double zoom = 16}) async {
    await _sub?.cancel();
    _sub = null;
    // Mark following immediately so the controls react without waiting for a
    // fix; the subscription is live and cancellable from this point on.
    state = true;
    _sub = ref
        .read(locationServiceProvider)
        .positionStream()
        .listen((LocationSample sample) => _move(sample, zoom));
    // Recenter now on the last known fix (unless a gesture turned follow off
    // while it was resolving).
    final LocationSample? known = await ref
        .read(locationServiceProvider)
        .lastKnown();
    if (state && known != null) {
      _move(known, zoom);
    }
  }

  void disable() {
    unawaited(_sub?.cancel());
    _sub = null;
    if (state) {
      state = false;
    }
  }

  Future<void> toggle({double zoom = 16}) async {
    if (state) {
      disable();
    } else {
      await enable(zoom: zoom);
    }
  }

  void _move(LocationSample sample, double zoom) {
    final MapService map = ref.read(mapServiceProvider);
    // A north lock survives fixes: only rotate with the device in heading mode.
    final MapOrientation orientation = ref.read(mapOrientationProvider);
    final double bearing = orientation == MapOrientation.north
        ? 0
        : (sample.bearing ?? 0);
    unawaited(
      map.moveCamera(
        map.camera.copyWith(
          target: sample.position,
          zoom: zoom,
          bearing: bearing,
        ),
        animated: true,
      ),
    );
  }
}

final NotifierProvider<FollowController, bool> followModeProvider =
    NotifierProvider<FollowController, bool>(FollowController.new);
