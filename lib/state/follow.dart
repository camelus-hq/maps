import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/location_sample.dart';
import '../domain/ports/map_service.dart';
import 'location.dart';
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
/// While enabled it subscribes to the [LocationTracker]'s fixes and recenters
/// the camera on each one, animating over roughly the fix interval so the map
/// glides instead of stepping. Enabling "flies" to the location with a short
/// animated zoom. The user taking over the map with a gesture (drag, pinch,
/// rotate or tilt) turns it off — so a pan isn't undone by the next fix.
class FollowController extends Notifier<bool> {
  /// The zoom "show my location" snaps to.
  static const double locationZoom = 17;

  /// The initial fly-to-location animation length.
  static const Duration flyDuration = Duration(milliseconds: 900);

  /// Bounds for the inferred smooth-follow animation length.
  static const Duration _minGlide = Duration(milliseconds: 250);
  static const Duration _maxGlide = Duration(milliseconds: 2000);

  StreamSubscription<void>? _gestureSub;
  double _zoom = locationZoom;
  DateTime? _lastFixAt;

  @override
  bool build() {
    // A direct map gesture means the user has taken over the camera; drop
    // follow so the map stays where they left it.
    _gestureSub = ref
        .read(mapServiceProvider)
        .userGestureStream
        .listen((_) => disable());
    // Follow every new fix that arrives while locked on.
    ref.listen<LocationState>(locationTrackerProvider, (
      LocationState? previous,
      LocationState next,
    ) {
      if (!state) {
        return;
      }
      final LocationSample? fix = next.fix;
      if (fix == null || identical(previous?.fix, fix)) {
        return;
      }
      _glide(fix);
    });
    ref.onDispose(() {
      unawaited(_gestureSub?.cancel());
    });
    return false;
  }

  /// Enables follow and flies to (and zooms in on) the location.
  Future<void> enable({double zoom = locationZoom}) async {
    _zoom = zoom;
    _lastFixAt = null;
    // Mark following immediately so the controls react without waiting for a
    // fix.
    state = true;
    final LocationSample? known =
        ref.read(locationTrackerProvider).fix ??
        await ref.read(locationServiceProvider).lastKnown();
    // A gesture may have turned follow off while the fix was resolving.
    if (!state || known == null) {
      return;
    }
    _fly(known, zoom);
  }

  void disable() {
    if (state) {
      state = false;
    }
  }

  Future<void> toggle({double zoom = locationZoom}) async {
    if (state) {
      disable();
    } else {
      await enable(zoom: zoom);
    }
  }

  /// The one-shot animated zoom into the location.
  void _fly(LocationSample sample, double zoom) {
    final MapService map = ref.read(mapServiceProvider);
    unawaited(
      map.moveCamera(
        map.camera.copyWith(
          target: sample.position,
          zoom: zoom,
          bearing: _bearingFor(sample.bearing),
        ),
        animated: true,
        duration: flyDuration,
      ),
    );
  }

  /// A continuous follow step: glide to [sample] over the fix interval.
  void _glide(LocationSample sample) {
    final MapService map = ref.read(mapServiceProvider);
    unawaited(
      map.moveCamera(
        map.camera.copyWith(
          target: sample.position,
          zoom: _zoom,
          bearing: _bearingFor(sample.bearing),
        ),
        animated: true,
        duration: _glideDuration(),
      ),
    );
  }

  double _bearingFor(double? bearing) =>
      ref.read(mapOrientationProvider) == MapOrientation.north
      ? 0
      : (bearing ?? 0);

  /// The animation length that keeps the camera gliding between fixes: roughly
  /// the time since the previous fix, so the next fix lands as the glide ends.
  Duration _glideDuration() {
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastFixAt;
    _lastFixAt = now;
    if (previous == null) {
      return _minGlide;
    }
    final int millis = now.difference(previous).inMilliseconds;
    if (millis <= _minGlide.inMilliseconds) {
      return _minGlide;
    }
    if (millis >= _maxGlide.inMilliseconds) {
      return _maxGlide;
    }
    return Duration(milliseconds: millis);
  }
}

final NotifierProvider<FollowController, bool> followModeProvider =
    NotifierProvider<FollowController, bool>(FollowController.new);
