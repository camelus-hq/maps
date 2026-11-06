import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/location_sample.dart';
import '../domain/entities/route.dart';
import '../domain/entities/travel_mode.dart';
import '../domain/ports/map_service.dart';
import 'follow.dart';
import 'location.dart';
import 'ports.dart';
import 'route.dart';
import 'usecases.dart';

enum NavStatus { idle, navigating, rerouting, arrived }

/// Immutable turn-by-turn guidance state.
class NavState {
  const NavState({
    this.status = NavStatus.idle,
    this.mode = TravelMode.drive,
    this.route,
    this.position,
    this.bearing,
    this.traveledMeters = 0,
    this.totalMeters = 0,
    this.remaining = Duration.zero,
    this.nextManeuver,
    this.distanceToNextManeuver = 0,
    this.maneuverIndex = 0,
    this.notice,
    this.overview = false,
    this.cameraFollows = true,
  });

  final NavStatus status;
  final TravelMode mode;
  final Route? route;
  final LatLon? position;
  final double? bearing;
  final double traveledMeters;
  final double totalMeters;
  final Duration remaining;
  final Maneuver? nextManeuver;
  final double distanceToNextManeuver;
  final int maneuverIndex;

  /// Non-fatal message (e.g. a failed reroute) for the guidance card.
  final String? notice;

  /// True while the camera shows the whole route instead of tracking.
  final bool overview;

  /// False while the user has taken the camera (panned/pinched away) so
  /// position updates no longer recenter it. Reset by re-centering.
  final bool cameraFollows;

  NavState copyWith({
    NavStatus? status,
    TravelMode? mode,
    Route? route,
    LatLon? position,
    double? bearing,
    double? traveledMeters,
    double? totalMeters,
    Duration? remaining,
    Maneuver? nextManeuver,
    double? distanceToNextManeuver,
    int? maneuverIndex,
    String? notice,
    bool clearNotice = false,
    bool? overview,
    bool? cameraFollows,
  }) => NavState(
    status: status ?? this.status,
    mode: mode ?? this.mode,
    route: route ?? this.route,
    position: position ?? this.position,
    bearing: bearing ?? this.bearing,
    traveledMeters: traveledMeters ?? this.traveledMeters,
    totalMeters: totalMeters ?? this.totalMeters,
    remaining: remaining ?? this.remaining,
    nextManeuver: nextManeuver ?? this.nextManeuver,
    distanceToNextManeuver:
        distanceToNextManeuver ?? this.distanceToNextManeuver,
    maneuverIndex: maneuverIndex ?? this.maneuverIndex,
    notice: clearNotice ? null : (notice ?? this.notice),
    overview: overview ?? this.overview,
    cameraFollows: cameraFollows ?? this.cameraFollows,
  );
}

/// Turn-by-turn guidance along a route.
///
/// Two position sources share one path: [step] (deterministic simulation, used
/// by the control channel and tests) and [handlePosition] (live GNSS behind the
/// `LocationService` port, when started with `live: true`). A live position that
/// drifts more than [_deviationMeters] off the route triggers a reroute (M5.3).
class NavigationController extends Notifier<NavState> {
  static const double _deviationMeters = 40;
  static const double _arrivalMeters = 20;

  Timer? _timer;
  StreamSubscription<void>? _gestureSub;

  /// True while guidance follows the live GNSS stream (via the tracker).
  bool _live = false;

  /// When the tracking camera was last asked to move (for smooth-follow speed).
  DateTime? _lastCameraMoveAt;

  List<LatLon> _geometry = const <LatLon>[];
  List<double> _cumulative = const <double>[];
  List<double> _maneuverEnds = const <double>[];

  @override
  NavState build() {
    // A user gesture (drag/pinch/rotate/tilt) stops the guidance camera from
    // tracking, so the map stays put instead of snapping back each step.
    _gestureSub = ref
        .read(mapServiceProvider)
        .userGestureStream
        .listen((_) => _onUserGesture());
    // Live GNSS positions (shared with follow through the tracker) drive
    // guidance while a live session is running.
    ref.listen<LocationState>(locationTrackerProvider, (
      LocationState? previous,
      LocationState next,
    ) {
      if (!_live) {
        return;
      }
      final LocationSample? fix = next.fix;
      if (fix == null || identical(previous?.fix, fix)) {
        return;
      }
      unawaited(handlePosition(fix));
    });
    ref.onDispose(() {
      _timer?.cancel();
      unawaited(_gestureSub?.cancel());
    });
    return const NavState();
  }

  void start(
    Route route, {
    bool auto = false,
    bool live = false,
    TravelMode mode = TravelMode.drive,
  }) {
    if (route.geometry.length < 2) {
      return;
    }
    _loadRoute(route);
    // Navigation owns the camera; stop follow mode so the two don't fight.
    ref.read(followModeProvider.notifier).disable();
    state = state.copyWith(
      status: NavStatus.navigating,
      mode: mode,
      overview: false,
      cameraFollows: true,
      clearNotice: true,
    );
    _timer?.cancel();
    _timer = null;
    _live = live;
    unawaited(_flyToCamera());
    if (auto) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (Timer _) => step(),
      );
    }
  }

  /// Advances the simulated position (control channel / UI tick).
  void step({double meters = 40}) {
    final Route? route = state.route;
    if (route == null || state.status != NavStatus.navigating) {
      return;
    }
    final double total = _cumulative.isEmpty ? 0 : _cumulative.last;
    final double traveled = math.min(state.traveledMeters + meters, total);
    _apply(routedTraveled: traveled, position: null, bearing: null);
    if (state.status == NavStatus.arrived) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Applies a real (or injected) position sample.
  Future<void> handlePosition(LocationSample sample) async {
    final Route? route = state.route;
    if (route == null ||
        state.status == NavStatus.idle ||
        state.status == NavStatus.arrived ||
        state.status == NavStatus.rerouting) {
      return;
    }
    final LatLon point = sample.position;
    final (int index, double deviation) = _nearestVertex(point);
    final double traveled = _cumulative.isEmpty ? 0 : _cumulative[index];
    if (deviation > _deviationMeters) {
      await _reroute(point);
      return;
    }
    if (state.totalMeters > 0 &&
        state.totalMeters - traveled <= _arrivalMeters) {
      state = state.copyWith(
        status: NavStatus.arrived,
        position: point,
        traveledMeters: state.totalMeters,
        remaining: Duration.zero,
        clearNotice: true,
      );
      _timer?.cancel();
      return;
    }
    _apply(routedTraveled: traveled, position: point, bearing: sample.bearing);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _live = false;
    state = const NavState();
  }

  /// Switches the travel mode of the running guidance session without touching
  /// the route or the map (the UI re-skins per mode; a future mixed-mode
  /// journey changes mode mid-route the same way).
  void setMode(TravelMode mode) {
    if (state.status == NavStatus.idle || state.mode == mode) {
      return;
    }
    state = state.copyWith(mode: mode);
  }

  /// Toggles between tracking the position and showing the whole route. While
  /// in overview, or after the user has taken the camera, position updates are
  /// ignored until tracking is resumed.
  void toggleOverview() {
    final Route? route = state.route;
    if (route == null || route.geometry.length < 2) {
      return;
    }
    final bool next = !state.overview;
    state = state.copyWith(overview: next, cameraFollows: !next);
    if (next) {
      unawaited(ref.read(mapServiceProvider).fitCoordinates(route.geometry));
    } else {
      unawaited(_flyToCamera());
    }
  }

  /// Stops the camera following the position (the user panned/pinched away).
  /// Guidance keeps running; the camera stays where the user left it.
  void pauseTracking() {
    if (!state.cameraFollows) {
      return;
    }
    state = state.copyWith(cameraFollows: false);
  }

  /// Re-centers the camera on the current position and resumes tracking.
  void resumeTracking() {
    if (state.route == null) {
      return;
    }
    state = state.copyWith(overview: false, cameraFollows: true);
    unawaited(_flyToCamera());
  }

  void _onUserGesture() {
    if (state.status != NavStatus.navigating) {
      return;
    }
    pauseTracking();
  }

  void _apply({
    required double routedTraveled,
    required LatLon? position,
    required double? bearing,
  }) {
    final Route? route = state.route;
    if (route == null) {
      return;
    }
    final double total = _cumulative.isEmpty ? 0 : _cumulative.last;
    if (total <= 0 || routedTraveled >= total) {
      state = state.copyWith(
        status: NavStatus.arrived,
        position: position ?? (_geometry.isEmpty ? null : _geometry.last),
        traveledMeters: total,
        totalMeters: total,
        remaining: Duration.zero,
        maneuverIndex: _maneuverEnds.length - 1,
        clearNotice: true,
      );
      return;
    }
    final (LatLon, double?) at = _positionAndBearing(routedTraveled);
    final int nextIndex = _nextManeuverIndex(routedTraveled);
    final List<Maneuver> maneuvers = _maneuvers(route);
    final Maneuver? next = nextIndex >= 0 && nextIndex < maneuvers.length
        ? maneuvers[nextIndex]
        : null;
    final double toNext = nextIndex >= 0 && nextIndex < _maneuverEnds.length
        ? (_maneuverEnds[nextIndex] - routedTraveled).clamp(0, double.infinity)
        : 0;
    final double fraction = total == 0
        ? 1
        : (routedTraveled / total).clamp(0, 1);
    state = state.copyWith(
      status: NavStatus.navigating,
      position: position ?? at.$1,
      bearing: bearing ?? at.$2,
      traveledMeters: routedTraveled,
      totalMeters: total,
      remaining: Duration(
        seconds: (route.duration.inSeconds * (1 - fraction)).round(),
      ),
      nextManeuver: next,
      distanceToNextManeuver: toNext,
      maneuverIndex: nextIndex < 0 ? 0 : nextIndex,
      clearNotice: true,
    );
    _moveCamera();
  }

  Future<void> _reroute(LatLon from) async {
    final Route? route = state.route;
    if (route == null || route.geometry.isEmpty) {
      return;
    }
    final LatLon destination = route.geometry.last;
    state = state.copyWith(status: NavStatus.rerouting);
    final Result<List<Route>> result = await ref.read(requestRouteProvider)(
      waypoints: <LatLon>[from, destination],
      mode: state.mode,
    );
    // stop() (or arrival) may have happened while the reroute was in flight;
    // never resurrect guidance from a stale response.
    if (state.status != NavStatus.rerouting) {
      return;
    }
    result.fold(
      ok: (List<Route> routes) {
        if (routes.isEmpty) {
          state = state.copyWith(
            status: NavStatus.navigating,
            notice: 'Reroute failed',
          );
          return;
        }
        final Route rerouted = routes.first;
        _loadRoute(rerouted);
        state = state.copyWith(status: NavStatus.navigating, clearNotice: true);
        // Redraw the polyline on the map (and keep the route preview in sync) so
        // the drawn path matches the new route after a reroute.
        ref.read(routeControllerProvider.notifier).replaceRoute(rerouted);
        _moveCamera();
      },
      err: (AppException error) => state = state.copyWith(
        status: NavStatus.navigating,
        notice: 'Reroute failed',
      ),
    );
  }

  void _loadRoute(Route route) {
    _geometry = route.geometry;
    _cumulative = _geometry.length >= 2
        ? _cumulativeDistances(_geometry)
        : const <double>[0];
    final double total = _cumulative.isEmpty ? 0 : _cumulative.last;
    _maneuverEnds = _maneuverCumulativeEnds(route, total);
    final List<Maneuver> maneuvers = _maneuvers(route);
    state = state.copyWith(
      route: route,
      totalMeters: total,
      traveledMeters: 0,
      remaining: route.duration,
      position: _geometry.isEmpty ? null : _geometry.first,
      nextManeuver: maneuvers.isEmpty ? null : maneuvers.first,
      distanceToNextManeuver: _maneuverEnds.isEmpty ? 0 : _maneuverEnds.first,
      maneuverIndex: 0,
    );
  }

  /// The initial fly to the navigation camera pose (a short animated zoom into
  /// the tilted tracking view).
  Future<void> _flyToCamera() async {
    if (state.overview || !state.cameraFollows) {
      return;
    }
    final LatLon? position = state.position;
    if (position == null) {
      return;
    }
    final MapService map = ref.read(mapServiceProvider);
    await map.moveCamera(
      Camera(target: position, zoom: 17, bearing: state.bearing ?? 0, tilt: 45),
      animated: true,
      duration: const Duration(milliseconds: 900),
    );
  }

  void _moveCamera() {
    // Overview or a user-browsed camera means we must not recenter.
    if (state.overview || !state.cameraFollows) {
      return;
    }
    final LatLon? position = state.position;
    if (position == null) {
      return;
    }
    final MapService map = ref.read(mapServiceProvider);
    unawaited(
      map.moveCamera(
        Camera(
          target: position,
          zoom: 17,
          bearing: state.bearing ?? 0,
          tilt: 45,
        ),
        animated: true,
        duration: _glideDuration(),
      ),
    );
  }

  /// The animation length that keeps the tracking camera gliding between fixes
  /// (roughly the time since the last one), so guidance moves smoothly instead
  /// of stepping each update.
  Duration _glideDuration() {
    final DateTime now = DateTime.now();
    final DateTime? previous = _lastCameraMoveAt;
    _lastCameraMoveAt = now;
    if (previous == null) {
      return const Duration(milliseconds: 300);
    }
    final int millis = now.difference(previous).inMilliseconds;
    return Duration(milliseconds: millis.clamp(200, 2000));
  }

  (int, double) _nearestVertex(LatLon point) {
    int best = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < _geometry.length; i++) {
      final double distance = _geometry[i].distanceTo(point);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    return (best, bestDistance);
  }

  List<double> _cumulativeDistances(List<LatLon> geometry) {
    final List<double> cumulative = <double>[0];
    for (int i = 1; i < geometry.length; i++) {
      cumulative.add(
        cumulative[i - 1] + geometry[i - 1].distanceTo(geometry[i]),
      );
    }
    return cumulative;
  }

  List<double> _maneuverCumulativeEnds(Route route, double total) {
    final List<double> ends = <double>[];
    double running = 0;
    for (final Leg leg in route.legs) {
      for (final Maneuver maneuver in leg.maneuvers) {
        running += maneuver.distanceMeters;
        ends.add(running.clamp(0, total));
      }
    }
    return ends;
  }

  List<Maneuver> _maneuvers(Route route) => <Maneuver>[
    for (final Leg leg in route.legs) ...leg.maneuvers,
  ];

  int _nextManeuverIndex(double traveled) {
    for (int i = 0; i < _maneuverEnds.length; i++) {
      if (traveled <= _maneuverEnds[i]) {
        return i;
      }
    }
    return _maneuverEnds.length - 1;
  }

  (LatLon, double?) _positionAndBearing(double traveled) {
    for (int i = 0; i < _geometry.length - 1; i++) {
      final double start = _cumulative[i];
      final double end = _cumulative[i + 1];
      if (traveled <= end || i == _geometry.length - 2) {
        final double segment = end - start;
        final double t = segment <= 0
            ? 0
            : ((traveled - start) / segment).clamp(0, 1);
        final LatLon from = _geometry[i];
        final LatLon to = _geometry[i + 1];
        final LatLon point = LatLon(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        );
        return (point, _bearing(from, to));
      }
    }
    return (_geometry.last, state.bearing);
  }

  double _bearing(LatLon from, LatLon to) {
    final double lat1 = from.latitude * math.pi / 180;
    final double lat2 = to.latitude * math.pi / 180;
    final double dLon = (to.longitude - from.longitude) * math.pi / 180;
    final double y = math.sin(dLon) * math.cos(lat2);
    final double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final double deg = math.atan2(y, x) * 180 / math.pi;
    return (deg + 360) % 360;
  }
}

final NotifierProvider<NavigationController, NavState>
navigationControllerProvider = NotifierProvider<NavigationController, NavState>(
  NavigationController.new,
);
