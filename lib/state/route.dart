import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/cycling_options.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/location_sample.dart';
import '../domain/entities/place.dart';
import '../domain/entities/route.dart';
import '../domain/entities/route_line.dart';
import '../domain/entities/transit.dart';
import '../domain/entities/transit_stop_marker.dart';
import '../domain/entities/travel_mode.dart';
import '../domain/ports/map_service.dart';
import 'follow.dart';
import 'ports.dart';
import 'usecases.dart';

enum RouteStatus { idle, loading, data, error }

/// The kind of endpoint a directions field maps to.
enum RouteEndpointField { origin, destination, stop }

/// A directions endpoint: the start, the destination, or an intermediate stop.
///
/// [stopIndex] is the index of an existing stop to edit; a `null` index on a
/// [RouteEndpointField.stop] target means "a new stop to be appended".
class RouteEndpointTarget {
  const RouteEndpointTarget(this.field, {this.stopIndex});

  const RouteEndpointTarget.origin()
    : field = RouteEndpointField.origin,
      stopIndex = null;

  const RouteEndpointTarget.destination()
    : field = RouteEndpointField.destination,
      stopIndex = null;

  const RouteEndpointTarget.stop([this.stopIndex])
    : field = RouteEndpointField.stop;

  final RouteEndpointField field;
  final int? stopIndex;

  /// Whether this target edits the stop at [index].
  bool get isExistingStop =>
      field == RouteEndpointField.stop && stopIndex != null && stopIndex! >= 0;

  @override
  bool operator ==(Object other) =>
      other is RouteEndpointTarget &&
      other.field == field &&
      other.stopIndex == stopIndex;

  @override
  int get hashCode => Object.hash(field, stopIndex);

  @override
  String toString() => field == RouteEndpointField.stop
      ? 'stop@${stopIndex ?? 'new'}'
      : field.name;
}

/// Immutable directions state for the route-preview sheet.
class RouteState {
  const RouteState({
    this.status = RouteStatus.idle,
    this.mode = TravelMode.cycle,
    this.routes = const <Route>[],
    this.selectedIndex = 0,
    this.origin,
    this.stops = const <Place>[],
    this.destination,
    this.pickTarget,
    this.editingEndpoint,
    this.error,
    this.itineraries = const <TransitItinerary>[],
    this.selectedItineraryIndex = 0,
    this.transitTimeMode = TransitTimeMode.leaveNow,
    this.transitTime,
    this.transitModes = const <TransitMode>{},
    this.fewerTransfers = false,
    this.lessWalking = false,
    this.transitDetailOpen = false,
    this.cycling = CyclingOptions.defaults,
  });

  final RouteStatus status;
  final TravelMode mode;
  final List<Route> routes;
  final int selectedIndex;
  final Place? origin;
  final List<Place> stops;
  final Place? destination;

  /// Set while the map is waiting for a long-press to fill this endpoint.
  final RouteEndpointTarget? pickTarget;

  /// The endpoint whose place picker (search UI) is open, or `null`.
  final RouteEndpointTarget? editingEndpoint;
  final AppException? error;

  /// Public-transport journeys, best first (only in [TravelMode.transit]).
  final List<TransitItinerary> itineraries;
  final int selectedItineraryIndex;
  final TransitTimeMode transitTimeMode;

  /// The requested departure/arrival time (`null` = leave now).
  final DateTime? transitTime;

  /// The transit modes the traveller prefers; empty means all.
  final Set<TransitMode> transitModes;
  final bool fewerTransfers;
  final bool lessWalking;

  /// True while the transit journey detail (step 2) is shown instead of the
  /// journey list (step 1).
  final bool transitDetailOpen;

  /// Bicycle cost tuning for a [TravelMode.cycle] route (bicycle type, hills,
  /// surface, road and speed weighting).
  final CyclingOptions cycling;

  Route? get selectedRoute =>
      selectedIndex >= 0 && selectedIndex < routes.length
      ? routes[selectedIndex]
      : null;

  TransitItinerary? get selectedItinerary =>
      selectedItineraryIndex >= 0 && selectedItineraryIndex < itineraries.length
      ? itineraries[selectedItineraryIndex]
      : null;

  /// Whether the sheet should present a public-transport journey.
  bool get isTransit => mode == TravelMode.transit;

  RouteState copyWith({
    RouteStatus? status,
    TravelMode? mode,
    List<Route>? routes,
    int? selectedIndex,
    Place? origin,
    List<Place>? stops,
    Place? destination,
    RouteEndpointTarget? pickTarget,
    RouteEndpointTarget? editingEndpoint,
    AppException? error,
    List<TransitItinerary>? itineraries,
    int? selectedItineraryIndex,
    TransitTimeMode? transitTimeMode,
    DateTime? transitTime,
    Set<TransitMode>? transitModes,
    bool? fewerTransfers,
    bool? lessWalking,
    bool? transitDetailOpen,
    CyclingOptions? cycling,
    bool clearError = false,
    bool clearDestination = false,
    bool clearPickTarget = false,
    bool clearEditingEndpoint = false,
    bool clearTransitTime = false,
  }) => RouteState(
    status: status ?? this.status,
    mode: mode ?? this.mode,
    routes: routes ?? this.routes,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    origin: origin ?? this.origin,
    stops: stops ?? this.stops,
    destination: clearDestination ? null : (destination ?? this.destination),
    pickTarget: clearPickTarget ? null : (pickTarget ?? this.pickTarget),
    editingEndpoint: clearEditingEndpoint
        ? null
        : (editingEndpoint ?? this.editingEndpoint),
    error: clearError ? null : (error ?? this.error),
    itineraries: itineraries ?? this.itineraries,
    selectedItineraryIndex:
        selectedItineraryIndex ?? this.selectedItineraryIndex,
    transitTimeMode: transitTimeMode ?? this.transitTimeMode,
    transitTime: clearTransitTime ? null : (transitTime ?? this.transitTime),
    transitModes: transitModes ?? this.transitModes,
    fewerTransfers: fewerTransfers ?? this.fewerTransfers,
    lessWalking: lessWalking ?? this.lessWalking,
    transitDetailOpen: transitDetailOpen ?? this.transitDetailOpen,
    cycling: cycling ?? this.cycling,
  );
}

/// Plans routes between editable endpoints and draws them on the map.
class RouteController extends Notifier<RouteState> {
  StreamSubscription<LatLon>? _longPressSub;

  /// True once the bicycle options changed without a request picking them up
  /// (a slider preview); the next committed change re-plans even if the value
  /// is unchanged from the last preview.
  bool _cyclingDirty = false;

  @override
  RouteState build() {
    // React to map long-presses so a picked endpoint can be filled without the
    // UI being on screen (agents drive `route.pickOnMap` then long-press).
    _longPressSub = ref
        .read(mapServiceProvider)
        .longPressStream
        .listen(_applyPickedPoint);
    ref.onDispose(() => unawaited(_longPressSub?.cancel()));
    return const RouteState();
  }

  /// Plans from the current location to [destination].
  Future<void> plan(Place destination) async {
    final Place? origin = await _currentLocationPlace();
    if (origin == null) {
      state = state.copyWith(
        status: RouteStatus.error,
        error: const UnknownException('Location is unavailable'),
      );
      return;
    }
    state = state.copyWith(
      status: RouteStatus.loading,
      origin: origin,
      destination: destination,
      stops: const <Place>[],
      clearError: true,
      clearPickTarget: true,
      clearEditingEndpoint: true,
    );
    if (state.mode.isTransit) {
      await _requestTransit();
      return;
    }
    await _request();
  }

  Future<void> setOrigin(Place origin) async {
    state = state.copyWith(origin: origin, clearError: true);
    await _replan();
  }

  Future<void> setDestination(Place destination) async {
    state = state.copyWith(destination: destination, clearError: true);
    await _replan();
  }

  Future<void> useCurrentLocation() =>
      useCurrentLocationFor(const RouteEndpointTarget.origin());

  /// Fills [target] with the device's current position (the "Your location"
  /// row in the endpoint place picker).
  Future<void> useCurrentLocationFor(RouteEndpointTarget target) async {
    final Place? location = await _currentLocationPlace();
    if (location == null) {
      return;
    }
    await applyEndpoint(target, location);
  }

  /// Applies [place] to the endpoint named by [target]: sets the start or
  /// destination, replaces an existing stop, or appends a new one.
  Future<void> applyEndpoint(RouteEndpointTarget target, Place place) async {
    switch (target.field) {
      case RouteEndpointField.origin:
        await setOrigin(place);
      case RouteEndpointField.destination:
        await setDestination(place);
      case RouteEndpointField.stop:
        final int? index = target.stopIndex;
        if (index == null) {
          await addStop(place);
        } else {
          await setStop(index, place);
        }
    }
  }

  /// Opens the place picker (the search UI) for [target].
  void openEndpointPicker(RouteEndpointTarget target) {
    state = state.copyWith(editingEndpoint: target, clearError: true);
  }

  /// Closes the endpoint place picker.
  void closeEndpointPicker() {
    state = state.copyWith(clearEditingEndpoint: true);
  }

  void swap() {
    final Place? origin = state.origin;
    final Place? destination = state.destination;
    if (origin == null || destination == null) {
      return;
    }
    state = state.copyWith(origin: destination, destination: origin);
    unawaited(_replan());
  }

  Future<void> addStop(Place stop) async {
    state = state.copyWith(
      stops: <Place>[...state.stops, stop],
      clearError: true,
    );
    await _replan();
  }

  /// Adds the current position as a stop (the "Add stop → Your location" path).
  Future<void> addStopAtCurrentLocation() async {
    final Place? location = await _currentLocationPlace();
    if (location != null) {
      await addStop(location);
    }
  }

  /// Replaces the stop at [index] and re-plans.
  Future<void> setStop(int index, Place stop) async {
    if (index < 0 || index >= state.stops.length) {
      return;
    }
    final List<Place> stops = <Place>[...state.stops]..[index] = stop;
    state = state.copyWith(stops: stops, clearError: true);
    await _replan();
  }

  /// Removes the stop at [index] and re-plans (the row's remove button).
  Future<void> removeStopAt(int index) async {
    if (index < 0 || index >= state.stops.length) {
      return;
    }
    final List<Place> stops = <Place>[...state.stops]..removeAt(index);
    state = state.copyWith(stops: stops, clearError: true);
    await _replan();
  }

  /// Arms the map so the next long-press fills [target].
  void beginPick(RouteEndpointTarget target) {
    state = state.copyWith(pickTarget: target);
  }

  void selectRoute(int index) {
    if (index < 0 || index >= state.routes.length) {
      return;
    }
    state = state.copyWith(selectedIndex: index);
    _draw(state.routes, index);
  }

  /// Replaces the selected route without changing the camera — used after a
  /// navigation reroute so the drawn polyline matches the new route while
  /// guidance keeps the tracking camera.
  void replaceRoute(Route route) {
    state = state.copyWith(
      status: RouteStatus.data,
      routes: <Route>[route],
      selectedIndex: 0,
      clearError: true,
    );
    _draw(<Route>[route], 0, fit: false);
  }

  Future<void> setMode(TravelMode mode) async {
    if (mode == state.mode) {
      return;
    }
    if (!mode.isTransit) {
      state = state.copyWith(
        mode: mode,
        clearError: true,
        itineraries: const <TransitItinerary>[],
        selectedItineraryIndex: 0,
        transitDetailOpen: false,
      );
      unawaited(
        ref
            .read(mapServiceProvider)
            .setTransitStopMarkers(const <TransitStopMarker>[]),
      );
      await _replan();
      return;
    }
    state = state.copyWith(
      mode: mode,
      clearError: true,
      routes: const <Route>[],
      itineraries: const <TransitItinerary>[],
      selectedItineraryIndex: 0,
      transitDetailOpen: false,
    );
    await _replan();
  }

  /// Applies bicycle cost options and re-plans; the options only affect a
  /// cycle route (they are forwarded to the router for `TravelMode.cycle`).
  ///
  /// Pass `replan: false` while a slider is being dragged so the thumb updates
  /// without firing a request per pixel. The drag's `onChangeEnd` call then
  /// re-plans once — even though the value is unchanged from the last preview —
  /// because the option set is marked dirty until a request picks it up.
  Future<void> setCyclingOptions(
    CyclingOptions options, {
    bool replan = true,
  }) async {
    if (options != state.cycling) {
      state = state.copyWith(cycling: options, clearError: true);
      _cyclingDirty = true;
    }
    if (replan && _cyclingDirty) {
      _cyclingDirty = false;
      await _replan();
    }
  }

  /// Selects a public-transport journey and draws it on the map.
  void selectItinerary(int index) {
    if (index < 0 || index >= state.itineraries.length) {
      return;
    }
    state = state.copyWith(selectedItineraryIndex: index);
    _drawTransit(state.itineraries[index]);
  }

  /// Opens the step-2 detail view for the journey at [index] (selecting and
  /// drawing it too).
  void openTransitDetail(int index) {
    if (index < 0 || index >= state.itineraries.length) {
      return;
    }
    state = state.copyWith(
      selectedItineraryIndex: index,
      transitDetailOpen: true,
    );
    _drawTransit(state.itineraries[index]);
  }

  /// Returns from the journey detail to the journey list.
  void closeTransitDetail() {
    if (!state.transitDetailOpen) {
      return;
    }
    state = state.copyWith(transitDetailOpen: false);
  }

  /// Sets the departure/arrival mode and an explicit time in one re-plan (the
  /// "Depart at"/"Arrive by" picker).
  Future<void> setTransitTimeOfDay(TransitTimeMode mode, DateTime? time) async {
    if (mode == TransitTimeMode.leaveNow) {
      state = state.copyWith(
        transitTimeMode: TransitTimeMode.leaveNow,
        clearTransitTime: true,
        clearError: true,
      );
    } else {
      state = state.copyWith(
        transitTimeMode: mode,
        transitTime: time ?? state.transitTime ?? _defaultTransitTime(),
        clearError: true,
      );
    }
    await _replan();
  }

  /// Changes when the transit journey should depart/arrive and re-plans.
  Future<void> setTransitTimeMode(TransitTimeMode timeMode) async {
    final DateTime? time = timeMode == TransitTimeMode.leaveNow
        ? null
        : (state.transitTime ?? _defaultTransitTime());
    state = state.copyWith(
      transitTimeMode: timeMode,
      transitTime: time,
      clearError: true,
      clearTransitTime: time == null,
    );
    await _replan();
  }

  /// Sets an explicit departure/arrival time and re-plans.
  Future<void> setTransitTime(DateTime? time) async {
    state = state.copyWith(
      transitTime: time,
      transitTimeMode: time == null
          ? TransitTimeMode.leaveNow
          : state.transitTimeMode == TransitTimeMode.leaveNow
          ? TransitTimeMode.departAt
          : state.transitTimeMode,
      clearError: true,
      clearTransitTime: time == null,
    );
    await _replan();
  }

  /// Toggles a "Prefer" transit group (Bus/Tram/Subway/Train/Ferry).
  Future<void> toggleTransitGroup(TransitModeGroup group) async {
    final Set<TransitMode> modes = <TransitMode>{...state.transitModes};
    final bool allSelected = group.modes.every(modes.contains);
    if (allSelected) {
      modes.removeAll(group.modes);
    } else {
      modes.addAll(group.modes);
    }
    state = state.copyWith(transitModes: modes, clearError: true);
    await _replan();
  }

  Future<void> setFewerTransfers(bool value) async {
    state = state.copyWith(fewerTransfers: value, clearError: true);
    await _replan();
  }

  Future<void> setLessWalking(bool value) async {
    state = state.copyWith(lessWalking: value, clearError: true);
    await _replan();
  }

  /// Applies several transit preferences at once (one re-plan, not three).
  Future<void> setTransitPreferences({
    Set<TransitMode>? modes,
    bool? fewerTransfers,
    bool? lessWalking,
  }) async {
    if (modes == null && fewerTransfers == null && lessWalking == null) {
      return;
    }
    state = state.copyWith(
      transitModes: modes,
      fewerTransfers: fewerTransfers,
      lessWalking: lessWalking,
      clearError: true,
    );
    await _replan();
  }

  /// Plans a public-transport journey between explicit endpoints (used by the
  /// control channel, and by any future transit entry point).
  Future<void> planTransit({
    required Place origin,
    required Place destination,
    List<Place> stops = const <Place>[],
    TransitTimeMode timeMode = TransitTimeMode.leaveNow,
    DateTime? time,
    Set<TransitMode> preferredModes = const <TransitMode>{},
    bool fewerTransfers = false,
    bool lessWalking = false,
  }) async {
    state = state.copyWith(
      mode: TravelMode.transit,
      origin: origin,
      destination: destination,
      stops: stops,
      status: RouteStatus.loading,
      routes: const <Route>[],
      itineraries: const <TransitItinerary>[],
      selectedItineraryIndex: 0,
      transitTimeMode: timeMode,
      transitTime: time,
      transitModes: preferredModes,
      fewerTransfers: fewerTransfers,
      lessWalking: lessWalking,
      transitDetailOpen: false,
      clearError: true,
      clearPickTarget: true,
      clearEditingEndpoint: true,
      clearTransitTime: time == null,
    );
    await _requestTransit();
  }

  void clear() {
    state = const RouteState();
    _cyclingDirty = false;
    final MapService map = ref.read(mapServiceProvider);
    unawaited(map.setRouteLines(const <RouteLine>[]));
    unawaited(map.setTransitStopMarkers(const <TransitStopMarker>[]));
  }

  /// Re-requests the route after a failure (error-state Retry button).
  Future<void> retry() async {
    if (state.origin == null || state.destination == null) {
      return;
    }
    state = state.copyWith(status: RouteStatus.loading, clearError: true);
    if (state.mode.isTransit) {
      await _requestTransit();
    } else {
      await _request();
    }
  }

  void _applyPickedPoint(LatLon point) {
    final RouteEndpointTarget? target = state.pickTarget;
    if (target == null) {
      return;
    }
    final Place picked = Place(
      id: 'picked-${point.latitude}-${point.longitude}',
      name: 'Dropped pin',
      position: point,
    );
    state = state.copyWith(clearPickTarget: true);
    unawaited(applyEndpoint(target, picked));
  }

  Future<void> _replan() async {
    if (state.origin == null || state.destination == null) {
      return;
    }
    state = state.copyWith(status: RouteStatus.loading);
    if (state.mode.isTransit) {
      await _requestTransit();
      return;
    }
    await _request();
  }

  Future<void> _request() async {
    final Place? origin = state.origin;
    final Place? destination = state.destination;
    if (origin == null || destination == null) {
      return;
    }
    final Result<List<Route>> result = await ref.read(requestRouteProvider)(
      waypoints: <LatLon>[
        origin.position,
        for (final Place stop in state.stops) stop.position,
        destination.position,
      ],
      mode: state.mode,
      cycling: state.mode == TravelMode.cycle ? state.cycling : null,
    );
    result.fold(
      ok: (List<Route> routes) {
        state = state.copyWith(
          status: RouteStatus.data,
          routes: routes,
          selectedIndex: 0,
          clearError: true,
        );
        _draw(routes, 0);
      },
      err: (AppException error) => state = state.copyWith(
        status: RouteStatus.error,
        routes: const <Route>[],
        error: error,
      ),
    );
  }

  /// Plans a public-transport journey through the transit port.
  Future<void> _requestTransit() async {
    final Place? origin = state.origin;
    final Place? destination = state.destination;
    if (origin == null || destination == null) {
      return;
    }
    final Result<List<TransitItinerary>> result =
        await ref.read(requestTransitRouteProvider)(
          TransitQuery(
            origin: origin.position,
            destination: destination.position,
            stops: <LatLon>[
              for (final Place stop in state.stops) stop.position,
            ],
            timeMode: state.transitTimeMode,
            time: state.transitTime,
            preferredModes: state.transitModes,
            fewerTransfers: state.fewerTransfers,
            lessWalking: state.lessWalking,
          ),
        );
    result.fold(
      ok: (List<TransitItinerary> itineraries) {
        state = state.copyWith(
          status: RouteStatus.data,
          itineraries: itineraries,
          selectedItineraryIndex: 0,
          transitDetailOpen: false,
          clearError: true,
        );
        _drawTransit(itineraries.first);
      },
      err: (AppException error) => state = state.copyWith(
        status: RouteStatus.error,
        itineraries: const <TransitItinerary>[],
        transitDetailOpen: false,
        error: error,
      ),
    );
    if (state.status == RouteStatus.error) {
      unawaited(
        ref
            .read(mapServiceProvider)
            .setTransitStopMarkers(const <TransitStopMarker>[]),
      );
    }
  }

  /// Draws a public-transport journey: one line per leg, in the operator's own
  /// colour for rides and a dashed neutral line for walking.
  void _drawTransit(TransitItinerary itinerary) {
    ref.read(followModeProvider.notifier).disable();
    final MapService map = ref.read(mapServiceProvider);
    final List<RouteLine> lines = <RouteLine>[
      for (final TransitLeg leg in itinerary.legs)
        if (leg.geometry.length >= 2)
          RouteLine(
            points: leg.geometry,
            color: leg.isTransit ? leg.displayColor : transitWalkColor,
            dashed: !leg.isTransit,
            width: leg.isTransit ? 6 : 4,
          ),
    ];
    unawaited(map.setRouteLines(lines));
    unawaited(map.setTransitStopMarkers(_stopMarkersFor(itinerary)));
    final List<LatLon> geometry = itinerary.geometry;
    if (geometry.length >= 2) {
      unawaited(map.fitCoordinates(geometry));
    }
  }

  /// The stops to draw for [itinerary]: a larger circle where the traveller
  /// boards or leaves a vehicle, a small one at every stop passed through. A
  /// transfer stop is drawn once (the larger circle wins).
  static List<TransitStopMarker> _stopMarkersFor(TransitItinerary itinerary) {
    final Map<String, TransitStopMarker> byPlace =
        <String, TransitStopMarker>{};
    void add(LatLon? position, bool board, int color) {
      final LatLon? point = position;
      if (point == null) {
        return;
      }
      final String key =
          '${point.latitude.toStringAsFixed(5)},${point.longitude.toStringAsFixed(5)}';
      final TransitStopMarker? existing = byPlace[key];
      if (existing != null && (existing.isBoard || !board)) {
        return;
      }
      byPlace[key] = TransitStopMarker(
        id: key,
        position: point,
        emphasis: board ? TransitStopEmphasis.board : TransitStopEmphasis.pass,
        color: color,
      );
    }

    for (final TransitLeg leg in itinerary.legs) {
      if (!leg.isTransit) {
        continue;
      }
      final int color = leg.displayColor;
      add(leg.from.position, true, color);
      add(leg.to.position, true, color);
      for (final TransitStop stop in leg.intermediateStops) {
        add(stop.position, false, color);
      }
    }
    return List<TransitStopMarker>.unmodifiable(byPlace.values);
  }

  /// The default "Depart at" / "Arrive by" time: now, rounded up to the next
  /// five minutes.
  static DateTime _defaultTransitTime() {
    final DateTime now = DateTime.now();
    final int rounded = ((now.minute + 4) ~/ 5) * 5;
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: rounded));
  }

  Future<Place?> _currentLocationPlace() async {
    final LocationSample? sample = await ref
        .read(locationServiceProvider)
        .lastKnown();
    if (sample == null) {
      return null;
    }
    return Place(
      id: 'current-location',
      name: 'Your location',
      position: sample.position,
    );
  }

  void _draw(List<Route> routes, int selectedIndex, {bool fit = true}) {
    // A route overview / preview takes camera ownership away from follow mode.
    ref.read(followModeProvider.notifier).disable();
    final MapService map = ref.read(mapServiceProvider);
    unawaited(
      map.setRouteLines(<RouteLine>[
        for (int i = 0; i < routes.length; i++)
          RouteLine(
            points: routes[i].geometry,
            color: i == selectedIndex ? 0xFF116B5B : 0xFF8A8F98,
            width: i == selectedIndex ? 6 : 4,
          ),
      ]),
    );
    unawaited(map.setTransitStopMarkers(const <TransitStopMarker>[]));
    final Route? selected = selectedIndex >= 0 && selectedIndex < routes.length
        ? routes[selectedIndex]
        : null;
    if (fit && selected != null && selected.geometry.isNotEmpty) {
      unawaited(map.fitCoordinates(selected.geometry));
    }
  }
}

final NotifierProvider<RouteController, RouteState> routeControllerProvider =
    NotifierProvider<RouteController, RouteState>(RouteController.new);
