import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/camera.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/location_sample.dart';
import '../domain/entities/navigation_camera.dart';
import '../domain/entities/route.dart';
import '../domain/entities/transit.dart';
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
    this.tripTraveledMeters = 0,
    this.speedMetersPerSecond,
    this.startedAt,
    this.remaining = Duration.zero,
    this.nextManeuver,
    this.distanceToNextManeuver = 0,
    this.maneuverIndex = 0,
    this.notice,
    this.overview = false,
    this.cameraFollows = true,
    this.transit,
    this.transitProgress,
  });

  final NavStatus status;
  final TravelMode mode;
  final Route? route;
  final LatLon? position;
  final double? bearing;

  /// Distance covered on the route currently being followed.
  final double traveledMeters;

  /// Full length of the route currently being followed.
  final double totalMeters;

  /// Distance actually covered since the trip began, carried across reroutes.
  ///
  /// A reroute replaces [route] (and resets [traveledMeters] to the start of
  /// the new line), so trip statistics must use this instead of
  /// [traveledMeters] to survive a re-plan.
  final double tripTraveledMeters;

  /// The smoothed current speed in metres per second, or `null` when unknown.
  ///
  /// Drives the tracking-camera zoom ([NavigationCamera]): the faster the
  /// traveller, the further the camera zooms out. It is `null` for a simulated
  /// session with no speed supplied, which is treated as stationary.
  final double? speedMetersPerSecond;

  /// When the current guidance trip started (wall clock), or `null` while
  /// idle. The trip's elapsed time is measured from here, so a reroute never
  /// restarts the clock.
  final DateTime? startedAt;

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

  /// The public-transport journey being followed, when the session is a transit
  /// one (drives the transit banner and the live timeline sheet).
  final TransitItinerary? transit;

  /// Where the traveller is on [transit], refreshed with every position update.
  final TransitProgress? transitProgress;

  NavState copyWith({
    NavStatus? status,
    TravelMode? mode,
    Route? route,
    LatLon? position,
    double? bearing,
    double? traveledMeters,
    double? totalMeters,
    double? tripTraveledMeters,
    double? speedMetersPerSecond,
    bool clearSpeed = false,
    DateTime? startedAt,
    Duration? remaining,
    Maneuver? nextManeuver,
    double? distanceToNextManeuver,
    int? maneuverIndex,
    String? notice,
    bool clearNotice = false,
    bool? overview,
    bool? cameraFollows,
    TransitItinerary? transit,
    TransitProgress? transitProgress,
  }) => NavState(
    status: status ?? this.status,
    mode: mode ?? this.mode,
    route: route ?? this.route,
    position: position ?? this.position,
    bearing: bearing ?? this.bearing,
    traveledMeters: traveledMeters ?? this.traveledMeters,
    totalMeters: totalMeters ?? this.totalMeters,
    tripTraveledMeters: tripTraveledMeters ?? this.tripTraveledMeters,
    speedMetersPerSecond: clearSpeed
        ? null
        : (speedMetersPerSecond ?? this.speedMetersPerSecond),
    startedAt: startedAt ?? this.startedAt,
    remaining: remaining ?? this.remaining,
    nextManeuver: nextManeuver ?? this.nextManeuver,
    distanceToNextManeuver:
        distanceToNextManeuver ?? this.distanceToNextManeuver,
    maneuverIndex: maneuverIndex ?? this.maneuverIndex,
    notice: clearNotice ? null : (notice ?? this.notice),
    overview: overview ?? this.overview,
    cameraFollows: cameraFollows ?? this.cameraFollows,
    transit: transit ?? this.transit,
    transitProgress: transitProgress ?? this.transitProgress,
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

  /// The smoothed speed estimate that drives the camera zoom, or `null` until a
  /// usable speed is seen.
  double? _speedMps;

  /// The previous fix and its time, used to estimate speed when the GNSS sample
  /// carries none.
  LatLon? _lastFixPosition;
  DateTime? _lastFixAt;

  /// The ride leg whose whole geometry is currently framed on the map while the
  /// traveller is on board (so the camera does not chase every fix).
  int? _fittedRideLeg;

  /// Consecutive live fixes whose position is out of step with the timetable.
  int _driftStreak = 0;

  /// When the journey was last re-planned for a schedule mismatch (cooldown).
  DateTime? _lastReplanAt;

  /// A mismatch (vs. the schedule) must exceed this to re-plan; it is generous
  /// because timetables are not always accurate. A false re-plan is worse than
  /// a slightly stale plan.
  static const Duration _driftThreshold = Duration(minutes: 6);

  /// How long to wait before another schedule re-plan.
  static const Duration _driftCooldown = Duration(minutes: 2);

  /// How many consecutive live fixes must be out of step before re-planning.
  static const int _driftFixesNeeded = 3;

  /// The itinerary's times must be within this window of "now" for a schedule
  /// comparison to be meaningful (a stale/fake plan is ignored).
  static const Duration _scheduleSanityWindow = Duration(hours: 3);

  List<LatLon> _geometry = const <LatLon>[];
  List<double> _cumulative = const <double>[];
  List<double> _maneuverEnds = const <double>[];

  /// Distance covered on route versions a reroute has since replaced. Added to
  /// the current route's [NavState.traveledMeters] to give the trip's covered
  /// distance, so a re-plan does not zero the trip statistics.
  double _tripTraveledBase = 0;

  /// The breadcrumb path actually covered this trip (the trail drawn in a
  /// distinct colour under the route). Kept across reroutes; cleared on
  /// start/stop.
  final List<LatLon> _trail = <LatLon>[];

  /// A trail point is only recorded once the traveller has moved this far, to
  /// keep the breadcrumb smooth and the redraws cheap.
  static const double _trailSpacingMeters = 4;

  /// Cap on recorded trail points (a bounded list: guidance can run for hours).
  static const int _trailMaxPoints = 4000;

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
    TransitItinerary? transit,
  }) {
    if (route.geometry.length < 2) {
      return;
    }
    _tripTraveledBase = 0;
    _trail.clear();
    _speedMps = null;
    _lastFixPosition = null;
    _lastFixAt = null;
    _loadRoute(route, transit: transit);
    // Navigation owns the camera; stop follow mode so the two don't fight.
    ref.read(followModeProvider.notifier).disable();
    state = state.copyWith(
      status: NavStatus.navigating,
      mode: mode,
      overview: false,
      cameraFollows: true,
      clearNotice: true,
      clearSpeed: true,
      // The trip clock starts here and survives every later reroute.
      startedAt: DateTime.now(),
      tripTraveledMeters: 0,
    );
    // Clear any trail left from a previous trip, then seed it with the start.
    final MapService map = ref.read(mapServiceProvider);
    unawaited(map.setTraveledPath(const <LatLon>[]));
    _recordTrail(state.position ?? route.geometry.first);
    _timer?.cancel();
    _timer = null;
    _live = live;
    _fittedRideLeg = null;
    _driftStreak = 0;
    _lastReplanAt = null;
    unawaited(_flyToCamera());
    if (auto) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 700),
        (Timer _) => step(),
      );
    }
  }

  /// Advances the simulated position (control channel / UI tick).
  ///
  /// [speedMetersPerSecond] optionally sets the simulated speed so the tracking
  /// camera zoom (see [NavigationCamera]) can be exercised without a live GNSS
  /// feed; omitting it leaves the last known speed untouched.
  void step({double meters = 40, double? speedMetersPerSecond}) {
    final Route? route = state.route;
    if (route == null || state.status != NavStatus.navigating) {
      return;
    }
    if (speedMetersPerSecond != null &&
        speedMetersPerSecond.isFinite &&
        speedMetersPerSecond >= 0) {
      _speedMps = speedMetersPerSecond;
    }
    final double total = _cumulative.isEmpty ? 0 : _cumulative.last;
    final double traveled = math.min(state.traveledMeters + meters, total);
    _apply(
      routedTraveled: traveled,
      position: null,
      bearing: null,
      speedMetersPerSecond: _speedMps,
    );
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
    _updateSpeed(sample);
    final (double traveled, double deviation) = _projectOntoRoute(point);
    // Record where the traveller actually went before any reroute branch, so
    // the trail keeps the off-route detour too.
    _recordTrail(point);
    // A public-transport journey is followed as-is: straying from the line
    // (GPS noise at a station, a parallel street) must not trigger a road
    // reroute — the provider's journey is not a drivable route.
    if (deviation > _deviationMeters && state.transit == null) {
      await _reroute(point);
      return;
    }
    if (state.totalMeters > 0 &&
        state.totalMeters - traveled <= _arrivalMeters) {
      state = state.copyWith(
        status: NavStatus.arrived,
        position: point,
        traveledMeters: state.totalMeters,
        tripTraveledMeters: _tripTraveledBase + state.totalMeters,
        remaining: Duration.zero,
        clearNotice: true,
        transitProgress: state.transit == null ? null : TransitProgress.arrived,
      );
      _timer?.cancel();
      return;
    }
    _apply(
      routedTraveled: traveled,
      position: point,
      bearing: sample.bearing,
      live: _live,
      speedMetersPerSecond: _speedMps,
    );
  }

  /// Updates the smoothed speed estimate from a fix.
  ///
  /// Prefers the GNSS-reported speed and, when the sample carries none, falls
  /// back to the distance between fixes over the elapsed time. Either way the
  /// value is smoothed (an exponential average) so the camera zoom glides with
  /// the traveller instead of jittering with the position noise.
  void _updateSpeed(LocationSample sample) {
    final DateTime now = DateTime.now();
    final double? reported = sample.speedMetersPerSecond;
    double? measured;
    if (reported != null && reported.isFinite && reported >= 0) {
      measured = reported;
    } else {
      final LatLon? previous = _lastFixPosition;
      final DateTime? previousAt = _lastFixAt;
      if (previous != null && previousAt != null) {
        final double seconds = now.difference(previousAt).inMilliseconds / 1000;
        if (seconds > 0.2) {
          measured = previous.distanceTo(sample.position) / seconds;
        }
      }
    }
    _lastFixPosition = sample.position;
    _lastFixAt = now;
    if (measured == null || !measured.isFinite || measured < 0) {
      return;
    }
    final double? previousSpeed = _speedMps;
    _speedMps = previousSpeed == null
        ? measured
        : previousSpeed * 0.6 + measured * 0.4;
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _live = false;
    _fittedRideLeg = null;
    _driftStreak = 0;
    _lastReplanAt = null;
    _tripTraveledBase = 0;
    _trail.clear();
    _speedMps = null;
    _lastFixPosition = null;
    _lastFixAt = null;
    state = const NavState();
    unawaited(ref.read(mapServiceProvider).setTraveledPath(const <LatLon>[]));
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

  /// The camera button action during guidance: re-center on the current position
  /// when the user has browsed the camera away, otherwise toggle the whole-route
  /// overview. This keeps the button label ("Re-center" vs "Route overview")
  /// honest — previously a panned map fell into the overview instead.
  void recenterOrOverview() {
    if (state.route == null) {
      return;
    }
    if (!state.overview && !state.cameraFollows) {
      resumeTracking();
    } else {
      toggleOverview();
    }
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
    bool live = false,
    double? speedMetersPerSecond,
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
        tripTraveledMeters: _tripTraveledBase + total,
        remaining: Duration.zero,
        maneuverIndex: _maneuverEnds.length - 1,
        clearNotice: true,
        transitProgress: state.transit == null ? null : TransitProgress.arrived,
      );
      return;
    }
    final (LatLon, double?) at = _positionAndBearing(routedTraveled);
    final LatLon resolved = position ?? at.$1;
    _recordTrail(resolved);
    final int segment = _segmentIndex(routedTraveled);
    final List<Maneuver> maneuvers = _maneuvers(route);
    // The banner announces the maneuver *ahead*, not the one just performed:
    // Valhalla's `length` covers the road after a maneuver, so the segment we
    // are on ends where the next maneuver's action happens. Without this the
    // banner keeps the previous turn's glyph (e.g. a right arrow while a left
    // turn is next).
    final int nextIndex = maneuvers.isEmpty
        ? -1
        : math.min(segment + 1, maneuvers.length - 1);
    final Maneuver? next = nextIndex >= 0 ? maneuvers[nextIndex] : null;
    final double toNext = segment >= 0 && segment < _maneuverEnds.length
        ? (_maneuverEnds[segment] - routedTraveled).clamp(0, double.infinity)
        : 0;
    final double fraction = total == 0
        ? 1
        : (routedTraveled / total).clamp(0, 1);
    final TransitProgress? progress = state.transit?.progressAt(routedTraveled);
    state = state.copyWith(
      status: NavStatus.navigating,
      position: resolved,
      bearing: bearing ?? at.$2,
      traveledMeters: routedTraveled,
      totalMeters: total,
      tripTraveledMeters: _tripTraveledBase + routedTraveled,
      speedMetersPerSecond: speedMetersPerSecond,
      // A transit journey is scheduled, not distance-paced: the time left is the
      // gap to the itinerary's arrival, so the ETA matches the timetable (a
      // road route is estimated from the distance covered).
      remaining: _remainingFor(route, fraction),
      nextManeuver: next,
      distanceToNextManeuver: toNext,
      maneuverIndex: nextIndex < 0 ? 0 : nextIndex,
      clearNotice: true,
      transitProgress: progress,
    );
    _updateTransitCamera(progress);
    if (live) {
      unawaited(_maybeReplanOnDrift(progress));
    }
  }

  /// Keeps the tracking camera sensible while a journey is followed.
  ///
  /// On foot the camera follows the traveller's position (with the flat transit
  /// pose). Once on board it frames the **whole ride section at once** and stays
  /// there, so the traveller can see the train's route rather than a churning
  /// close-up — reframing only when the ride leg changes or tracking resumes.
  void _updateTransitCamera(TransitProgress? progress) {
    if (progress == null || !progress.onBoard) {
      _fittedRideLeg = null;
      _moveCamera();
      return;
    }
    // The traveller is browsing the map themselves — don't reframe under them.
    if (state.overview || !state.cameraFollows) {
      return;
    }
    final int? legIndex = progress.rideLegIndex;
    final TransitLeg? ride = progress.ride;
    if (legIndex == null || ride == null || ride.geometry.length < 2) {
      _moveCamera();
      return;
    }
    if (_fittedRideLeg == legIndex) {
      // The whole section is already framed; leave the camera steady.
      return;
    }
    _fittedRideLeg = legIndex;
    unawaited(ref.read(mapServiceProvider).fitCoordinates(ride.geometry));
  }

  /// Compares where the traveller actually is with where the timetable says
  /// they should be. A sustained, large mismatch (they caught an earlier train,
  /// missed one, or the plan is stale) re-plans the journey from the current
  /// position — conservatively, because timetable data is not always accurate.
  Future<void> _maybeReplanOnDrift(TransitProgress? progress) async {
    final TransitItinerary? transit = state.transit;
    if (transit == null || transit.legs.isEmpty || progress == null) {
      _driftStreak = 0;
      return;
    }
    // Only a ride leg can be matched: walking pace varies, and the timetable
    // says nothing about it.
    if (!progress.onBoard) {
      _driftStreak = 0;
      return;
    }
    final DateTime now = DateTime.now();
    // Ignore a stale or synthetic plan whose times are nowhere near "now".
    if (now.difference(transit.startTime).abs() > _scheduleSanityWindow) {
      _driftStreak = 0;
      return;
    }
    final TransitLeg leg = transit.legs[progress.legIndex];
    final DateTime scheduledAtPosition = leg.startTime.add(
      Duration(
        seconds: (leg.duration.inSeconds * progress.fractionInLeg).round(),
      ),
    );
    final Duration drift = now.difference(scheduledAtPosition);
    if (drift.abs() <= _driftThreshold) {
      _driftStreak = 0;
      return;
    }
    _driftStreak++;
    final DateTime? last = _lastReplanAt;
    if (_driftStreak < _driftFixesNeeded ||
        (last != null && now.difference(last) < _driftCooldown)) {
      return;
    }
    _driftStreak = 0;
    _lastReplanAt = now;
    await _replanTransit(state.position);
  }

  /// Re-plans the journey from [from] (the current position) to its
  /// destination, then continues guidance along the new itinerary.
  Future<void> _replanTransit(LatLon? from) async {
    final TransitItinerary? transit = state.transit;
    if (transit == null || transit.legs.isEmpty) {
      return;
    }
    final LatLon? start =
        from ??
        transit.originStop?.position ??
        (transit.geometry.isEmpty ? null : transit.geometry.first);
    final LatLon? destination =
        transit.legs.last.to.position ??
        (transit.geometry.isEmpty ? null : transit.geometry.last);
    if (start == null || destination == null) {
      return;
    }
    state = state.copyWith(
      status: NavStatus.rerouting,
      notice: 'Updating your journey…',
    );
    final Result<List<TransitItinerary>> result = await ref.read(
      requestTransitRouteProvider,
    )(TransitQuery(origin: start, destination: destination));
    // stop() (or arrival) may have happened while the re-plan was in flight.
    if (state.status != NavStatus.rerouting) {
      return;
    }
    result.fold(
      ok: (List<TransitItinerary> itineraries) {
        if (itineraries.isEmpty) {
          state = state.copyWith(
            status: NavStatus.navigating,
            notice: 'Journey update failed',
          );
          return;
        }
        _fittedRideLeg = null;
        _loadRoute(itineraries.first.toRoute(), transit: itineraries.first);
        state = state.copyWith(status: NavStatus.navigating, clearNotice: true);
        ref
            .read(routeControllerProvider.notifier)
            .replaceTransitItineraries(itineraries, 0);
        unawaited(_flyToCamera());
      },
      err: (AppException error) => state = state.copyWith(
        status: NavStatus.navigating,
        notice: 'Journey update failed',
      ),
    );
  }

  /// The time left for the running journey.
  ///
  /// A transit journey is scheduled, so the time left is the gap to the
  /// itinerary's arrival (this also recomputes the moment a re-plan lands);
  /// a road route is estimated from the distance covered.
  Duration _remainingFor(Route route, double fraction) {
    final Duration? scheduled = _scheduledRemaining(state.transit);
    if (scheduled != null) {
      return scheduled;
    }
    return Duration(
      seconds: (route.duration.inSeconds * (1 - fraction)).round(),
    );
  }

  /// The scheduled gap to [transit]'s arrival, or `null` when there is no
  /// itinerary or its arrival already passed (fall back to a distance estimate).
  static Duration? _scheduledRemaining(TransitItinerary? transit) {
    if (transit == null) {
      return null;
    }
    final Duration left = transit.endTime.difference(DateTime.now());
    return left.isNegative ? null : left;
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
        // Carry the distance already covered on the replaced route into the
        // trip total, so the trip statistics survive the reroute.
        _tripTraveledBase += state.traveledMeters;
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

  void _loadRoute(Route route, {TransitItinerary? transit}) {
    _geometry = route.geometry;
    _cumulative = _geometry.length >= 2
        ? _cumulativeDistances(_geometry)
        : const <double>[0];
    final double total = _cumulative.isEmpty ? 0 : _cumulative.last;
    _maneuverEnds = _maneuverCumulativeEnds(route, total);
    final List<Maneuver> maneuvers = _maneuvers(route);
    // At the start we are on the first segment, so the announced maneuver is
    // the one ahead (see `_apply`).
    final int nextIndex = maneuvers.isEmpty
        ? -1
        : math.min(_segmentIndex(0) + 1, maneuvers.length - 1);
    state = state.copyWith(
      route: route,
      totalMeters: total,
      traveledMeters: 0,
      tripTraveledMeters: _tripTraveledBase,
      remaining: _scheduledRemaining(transit) ?? route.duration,
      position: _geometry.isEmpty ? null : _geometry.first,
      nextManeuver: nextIndex < 0 ? null : maneuvers[nextIndex],
      distanceToNextManeuver: _maneuverEnds.isEmpty ? 0 : _maneuverEnds.first,
      maneuverIndex: nextIndex < 0 ? 0 : nextIndex,
      transit: transit,
      transitProgress: transit?.progressAt(0),
    );
  }

  /// Records [point] on the trip's breadcrumb trail and redraws it, skipping
  /// points closer than [_trailSpacingMeters] and bounding the list.
  void _recordTrail(LatLon point) {
    if (_trail.isNotEmpty &&
        _trail.last.distanceTo(point) < _trailSpacingMeters) {
      return;
    }
    _trail.add(point);
    if (_trail.length > _trailMaxPoints) {
      _trail.removeRange(0, _trail.length - _trailMaxPoints);
    }
    unawaited(
      ref
          .read(mapServiceProvider)
          .setTraveledPath(List<LatLon>.unmodifiable(_trail)),
    );
  }

  /// The initial fly to the navigation camera pose. On foot this is a short
  /// animated zoom into the tracking view; on board a transit ride it frames the
  /// whole ride section instead.
  Future<void> _flyToCamera() async {
    if (state.overview || !state.cameraFollows) {
      return;
    }
    final MapService map = ref.read(mapServiceProvider);
    final TransitProgress? progress = state.transitProgress;
    final TransitLeg? ride = progress?.ride;
    if (progress != null &&
        progress.onBoard &&
        ride != null &&
        ride.geometry.length >= 2) {
      _fittedRideLeg = progress.rideLegIndex;
      await map.fitCoordinates(ride.geometry);
      return;
    }
    final LatLon? position = state.position;
    if (position == null) {
      return;
    }
    await map.moveCamera(
      _trackingPose(position),
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
        _trackingPose(position),
        animated: true,
        duration: _glideDuration(),
      ),
    );
  }

  /// The tracking camera pose for the running session. Transit guidance keeps
  /// the map north-up and flat (as transit apps do), centred on the traveller;
  /// the road modes tilt into the heading so the route reads ahead and zoom out
  /// with the traveller's speed, holding the close-in zoom as a turn nears
  /// ([NavigationCamera]).
  Camera _trackingPose(LatLon position) => state.mode == TravelMode.transit
      ? Camera(
          target: position,
          zoom: NavigationCamera.transitZoom,
          bearing: 0,
          tilt: 0,
        )
      : Camera(
          target: position,
          zoom: NavigationCamera.zoom(
            mode: state.mode,
            speedMetersPerSecond: state.speedMetersPerSecond,
            nextManeuver: state.nextManeuver,
            distanceToNextManeuver: state.distanceToNextManeuver,
          ),
          bearing: state.bearing ?? 0,
          tilt: 45,
        );

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

  /// Locates [point] on the route: the distance travelled along the polyline
  /// (interpolated **within** a segment, so it advances with every fix rather
  /// than snapping to the next vertex) and the perpendicular distance from the
  /// route ([_deviationMeters] is measured against this).
  (double, double) _projectOntoRoute(LatLon point) {
    if (_geometry.isEmpty) {
      return (0, double.infinity);
    }
    if (_geometry.length == 1) {
      return (0, _geometry.first.distanceTo(point));
    }
    double bestTraveled = 0;
    double bestDeviation = double.infinity;
    for (int i = 0; i + 1 < _geometry.length; i++) {
      final (double t, double deviation) = _projectOnSegment(
        point,
        _geometry[i],
        _geometry[i + 1],
      );
      if (deviation < bestDeviation) {
        bestDeviation = deviation;
        bestTraveled =
            _cumulative[i] + (_cumulative[i + 1] - _cumulative[i]) * t;
      }
    }
    return (bestTraveled, bestDeviation);
  }

  /// Projects [point] onto the segment [a]–[b], returning the clamped fraction
  /// `t` from [a] to [b] and the perpendicular distance in metres. Uses a local
  /// equirectangular projection (plenty accurate at street scale).
  static (double, double) _projectOnSegment(LatLon point, LatLon a, LatLon b) {
    const double metersPerDegree = 111320;
    final double cosLat = math
        .cos(point.latitude * math.pi / 180)
        .abs()
        .clamp(0.01, 1.0);
    double x(LatLon q) =>
        (q.longitude - point.longitude) * metersPerDegree * cosLat;
    double y(LatLon q) => (q.latitude - point.latitude) * metersPerDegree;
    final double ax = x(a);
    final double ay = y(a);
    final double dx = x(b) - ax;
    final double dy = y(b) - ay;
    final double lengthSquared = dx * dx + dy * dy;
    final double t = lengthSquared <= 0
        ? 0
        : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
    final double px = ax + dx * t;
    final double py = ay + dy * t;
    return (t, math.sqrt(px * px + py * py));
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

  /// The index of the segment the position is on. Its end ([_maneuverEnds]) is
  /// where the following maneuver's action happens, so the announced maneuver
  /// is `_segmentIndex(traveled) + 1`.
  int _segmentIndex(double traveled) {
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
