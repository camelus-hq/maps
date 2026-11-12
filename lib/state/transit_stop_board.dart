import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/place.dart';
import '../domain/entities/route_line.dart';
import '../domain/entities/transit.dart';
import '../domain/entities/transit_stop_marker.dart';
import '../domain/ports/map_service.dart';
import 'place.dart';
import 'ports.dart';
import 'route.dart';
import 'usecases.dart';

enum StopBoardStatus { idle, loading, data, error }

/// The state of the "Departures" tab for a tapped public-transport stop: the
/// resolved stop, the lines serving it, the paged departures and the loaded line
/// shapes (drawn on the map).
class TransitStopBoardState {
  const TransitStopBoardState({
    this.status = StopBoardStatus.idle,
    this.placeId,
    this.stopId,
    this.stopName,
    this.position,
    this.routes = const <TransitStopRoute>[],
    this.departures = const <TransitStopDeparture>[],
    this.lines = const <TransitStopLine>[],
    this.loadingEarlier = false,
    this.loadingLater = false,
    this.canLoadEarlier = true,
    this.canLoadLater = true,
    this.selectedDeparture,
    this.tripDetail,
    this.tripLoading = false,
    this.tripError,
    this.error,
  });

  final StopBoardStatus status;

  /// The id of the place that opened the board (the map POI/search result).
  final String? placeId;

  /// The provider's canonical stop id, once resolved.
  final String? stopId;

  /// The resolved stop's display name (falls back to the place name).
  final String? stopName;

  /// The stop coordinate the board is anchored on.
  final LatLon? position;

  /// The lines serving the stop (for the line chips).
  final List<TransitStopRoute> routes;

  /// The departures loaded so far, earliest first.
  final List<TransitStopDeparture> departures;

  /// The line shapes drawn on the map for this stop.
  final List<TransitStopLine> lines;

  final bool loadingEarlier;
  final bool loadingLater;
  final bool canLoadEarlier;
  final bool canLoadLater;

  /// The departure whose train detail is open, if any.
  final TransitStopDeparture? selectedDeparture;

  /// The open train's full detail (line, shape, every stop with its time).
  final TransitStopLine? tripDetail;

  /// Whether the train detail is loading.
  final bool tripLoading;

  /// A failure loading the train detail.
  final AppException? tripError;

  final AppException? error;

  /// Whether the board is active (a stop is selected).
  bool get isOpen => status != StopBoardStatus.idle;

  bool get isLoading => status == StopBoardStatus.loading;

  bool get hasEarlier => canLoadEarlier && departures.isNotEmpty;

  bool get hasLater => canLoadLater && departures.isNotEmpty;

  /// Whether a single train's detail is showing.
  bool get hasTripDetail =>
      selectedDeparture != null || tripDetail != null || tripLoading;

  TransitStopBoardState copyWith({
    StopBoardStatus? status,
    String? placeId,
    String? stopId,
    String? stopName,
    LatLon? position,
    List<TransitStopRoute>? routes,
    List<TransitStopDeparture>? departures,
    List<TransitStopLine>? lines,
    bool? loadingEarlier,
    bool? loadingLater,
    bool? canLoadEarlier,
    bool? canLoadLater,
    TransitStopDeparture? selectedDeparture,
    TransitStopLine? tripDetail,
    bool? tripLoading,
    AppException? tripError,
    AppException? error,
    bool clearError = false,
    bool clearTrip = false,
  }) {
    return TransitStopBoardState(
      status: status ?? this.status,
      placeId: placeId ?? this.placeId,
      stopId: stopId ?? this.stopId,
      stopName: stopName ?? this.stopName,
      position: position ?? this.position,
      routes: routes ?? this.routes,
      departures: departures ?? this.departures,
      lines: lines ?? this.lines,
      loadingEarlier: loadingEarlier ?? this.loadingEarlier,
      loadingLater: loadingLater ?? this.loadingLater,
      canLoadEarlier: canLoadEarlier ?? this.canLoadEarlier,
      canLoadLater: canLoadLater ?? this.canLoadLater,
      selectedDeparture: clearTrip
          ? null
          : (selectedDeparture ?? this.selectedDeparture),
      tripDetail: clearTrip ? null : (tripDetail ?? this.tripDetail),
      tripLoading: clearTrip ? false : (tripLoading ?? this.tripLoading),
      tripError: clearTrip ? null : (tripError ?? this.tripError),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Loads the departures for a tapped map stop and draws its lines on the map.
///
/// The board is opened by the place sheet when a transit stop is selected. It
/// resolves the stop's static info (name + lines) and its first page of
/// departures in parallel, then fetches one representative trip per line to draw
/// the whole line on the map. "Load earlier/later" pages around the loaded
/// departure times so the board moves through the day.
class TransitStopBoardController extends Notifier<TransitStopBoardState> {
  /// How far before "now" the first page starts, so a just-left departure stays
  /// visible as the list opens.
  static const Duration _pastWindow = Duration(minutes: 1);

  /// Departures per page.
  static const int _pageSize = 12;

  /// Hard cap on the rows kept while paging, so the list cannot grow forever.
  static const int _maxRows = 120;

  /// How many distinct lines to draw on the map.
  static const int _maxLines = 6;

  /// The neutral ring colour for a stop with no line colour (matches the map's
  /// own default).
  static const int _defaultColor = 0xFF116B5B;

  int _requestId = 0;
  bool _drewMap = false;

  @override
  TransitStopBoardState build() {
    // The board lives with the selected place: deselecting it (or selecting
    // another place) closes the board and clears the lines it drew, so they
    // never linger after the station sheet is closed.
    ref.listen<Place?>(selectedPlaceProvider, (Place? _, Place? next) {
      if (!state.isOpen) {
        return;
      }
      if (next == null || next.id != state.placeId) {
        close();
      }
    });
    return const TransitStopBoardState();
  }

  /// Opens the board for a transit [place] (a map POI or a search result),
  /// resolving the stop and drawing its lines.
  Future<void> openFromPlace(Place place) =>
      _open(placeId: place.id, stopName: place.name, position: place.position);

  /// Opens the board for a bare coordinate (a stop tapped without a place).
  Future<void> openAt({required LatLon position, String? name}) =>
      _open(placeId: null, stopName: name, position: position);

  Future<void> _open({
    required String? placeId,
    required String? stopName,
    required LatLon position,
    String? stopId,
  }) async {
    final int request = ++_requestId;
    await _clearMap();
    state = TransitStopBoardState(
      status: StopBoardStatus.loading,
      placeId: placeId,
      stopId: stopId,
      stopName: stopName,
      position: position,
    );

    final TransitStopQuery stopQuery = TransitStopQuery(
      stopId: stopId,
      position: position,
    );
    final TransitDeparturesQuery departuresQuery = TransitDeparturesQuery(
      stopId: stopId,
      position: position,
      time: DateTime.now().subtract(_pastWindow),
      limit: _pageSize,
    );

    final (
      Result<TransitStopInfo> info,
      Result<List<TransitStopDeparture>> page,
    ) = await (
      ref.read(requestStopInfoProvider)(stopQuery),
      ref.read(requestStopDeparturesProvider)(departuresQuery),
    ).wait;
    if (request != _requestId || !ref.mounted) {
      return;
    }

    final TransitStopInfo? stop = info.valueOrNull;
    final bool hasStopId = stop != null && stop.stopId.isNotEmpty;
    final TransitStopBoardState resolved = state.copyWith(
      stopId: hasStopId ? stop.stopId : null,
      stopName: hasStopId ? stop.name : null,
      position: hasStopId ? (stop.position ?? state.position) : null,
      routes: stop?.routes,
    );
    if (page case Ok<List<TransitStopDeparture>>(value: final rows)) {
      state = resolved.copyWith(
        status: StopBoardStatus.data,
        departures: rows,
        clearError: true,
      );
      await _loadLines(request, rows);
    } else if (page case Err<List<TransitStopDeparture>>(error: final error)) {
      state = resolved.copyWith(status: StopBoardStatus.error, error: error);
    }
  }

  /// Re-runs the initial load for the stop already selected.
  Future<void> retry() async {
    final LatLon? position = state.position;
    if (position == null) {
      return;
    }
    await _open(
      placeId: state.placeId,
      stopName: state.stopName,
      position: position,
      stopId: state.stopId,
    );
  }

  /// Loads the departures before the earliest one currently shown.
  Future<void> loadEarlier() async {
    final List<TransitStopDeparture> rows = state.departures;
    if (state.loadingEarlier || !state.canLoadEarlier || rows.isEmpty) {
      return;
    }
    await _page(
      direction: TransitDeparturesDirection.earlier,
      anchor: rows.first.displayDeparture.subtract(const Duration(seconds: 1)),
      prepend: true,
    );
  }

  /// Loads the departures after the latest one currently shown.
  Future<void> loadLater() async {
    final List<TransitStopDeparture> rows = state.departures;
    if (state.loadingLater || !state.canLoadLater || rows.isEmpty) {
      return;
    }
    await _page(
      direction: TransitDeparturesDirection.later,
      anchor: rows.last.displayDeparture,
      prepend: false,
    );
  }

  Future<void> _page({
    required TransitDeparturesDirection direction,
    required DateTime anchor,
    required bool prepend,
  }) async {
    final LatLon? position = state.position;
    if (state.stopId == null && position == null) {
      return;
    }
    final bool earlier = direction == TransitDeparturesDirection.earlier;
    final int request = _requestId;
    state = state.copyWith(loadingEarlier: earlier, loadingLater: !earlier);
    final Result<List<TransitStopDeparture>> result =
        await ref.read(requestStopDeparturesProvider)(
          TransitDeparturesQuery(
            stopId: state.stopId,
            position: position,
            time: anchor,
            limit: _pageSize,
            direction: direction,
          ),
        );
    if (request != _requestId || !ref.mounted) {
      return;
    }
    result.fold(
      ok: (List<TransitStopDeparture> rows) {
        final List<TransitStopDeparture> existing = state.departures;
        final Set<String> seen = existing.map(_rowKey).toSet();
        final List<TransitStopDeparture> fresh = <TransitStopDeparture>[
          for (final TransitStopDeparture row in rows)
            if (seen.add(_rowKey(row))) row,
        ];
        final List<TransitStopDeparture> combined = prepend
            ? <TransitStopDeparture>[...fresh, ...existing]
            : <TransitStopDeparture>[...existing, ...fresh];
        final List<TransitStopDeparture> capped = combined.length <= _maxRows
            ? combined
            : (prepend
                  ? combined.sublist(0, _maxRows)
                  : combined.sublist(combined.length - _maxRows));
        state = state.copyWith(
          departures: capped,
          loadingEarlier: false,
          loadingLater: false,
          canLoadEarlier: earlier ? fresh.isNotEmpty : state.canLoadEarlier,
          canLoadLater: earlier ? state.canLoadLater : fresh.isNotEmpty,
        );
      },
      // A failed page keeps the rows already shown; the button can be retried.
      err: (AppException _) =>
          state = state.copyWith(loadingEarlier: false, loadingLater: false),
    );
  }

  /// Closes the board and clears the lines it drew (unless a route now owns the
  /// map).
  void close() {
    _requestId++;
    state = const TransitStopBoardState();
    unawaited(_clearMap());
  }

  /// Closes the board only when it is open for [placeId] — used when a place
  /// sheet is disposed, so a sheet replacing it (under the sheet switcher) does
  /// not close the board it just opened.
  void closeFor(String placeId) {
    if (state.isOpen && state.placeId == placeId) {
      close();
    }
  }

  /// Fetches one representative trip per line and draws the whole line on the
  /// map (shape + every stop), like the public-transport journey drawing. Only
  /// the local/regional lines are drawn (a main station's long-distance numbers
  /// would be noise); if the stop is served only by long-distance trains, all
  /// lines are drawn.
  Future<void> _loadLines(
    int request,
    List<TransitStopDeparture> departures,
  ) async {
    final List<TransitStopDeparture> local = <TransitStopDeparture>[
      for (final TransitStopDeparture departure in departures)
        if (!departure.mode.isLongDistance) departure,
    ];
    final List<TransitStopDeparture> chosen = local.isEmpty
        ? departures
        : local;

    final Map<String, ({TransitStopDeparture departure, String tripId})>
    byLine = <String, ({TransitStopDeparture departure, String tripId})>{};
    for (final TransitStopDeparture departure in chosen) {
      final String tripId = departure.tripId?.trim() ?? '';
      if (tripId.isEmpty) {
        continue;
      }
      byLine.putIfAbsent(
        _lineKey(departure),
        () => (departure: departure, tripId: tripId),
      );
    }

    final List<TransitStopLine> lines = <TransitStopLine>[];
    for (final ({TransitStopDeparture departure, String tripId}) entry
        in byLine.values.take(_maxLines)) {
      final Result<TransitItinerary> result = await ref.read(
        requestTransitTripProvider,
      )(entry.tripId);
      if (request != _requestId || !ref.mounted) {
        return;
      }
      final TransitStopLine? line = _lineFromItinerary(
        result.valueOrNull,
        entry.departure,
      );
      if (line != null) {
        lines.add(line);
      }
    }
    if (request != _requestId || !ref.mounted) {
      return;
    }
    state = state.copyWith(lines: lines);
    await _drawLines();
  }

  /// Builds a drawable line (shape + every stop) from a `/trip` itinerary,
  /// using the departure as the fallback for the line's identity.
  static TransitStopLine? _lineFromItinerary(
    TransitItinerary? itinerary,
    TransitStopDeparture departure,
  ) {
    if (itinerary == null) {
      return null;
    }
    final List<TransitLeg> transitLegs = itinerary.transitLegs;
    final TransitLeg? leg = transitLegs.isNotEmpty
        ? transitLegs.first
        : (itinerary.legs.isNotEmpty ? itinerary.legs.first : null);
    if (leg == null || leg.geometry.length < 2) {
      return null;
    }
    return TransitStopLine(
      route: TransitStopRoute(
        mode: leg.mode,
        routeShortName: leg.routeShortName ?? departure.routeShortName,
        routeLongName: leg.routeLongName ?? departure.routeLongName,
        agencyName: leg.agencyName ?? departure.agencyName,
        routeColor: leg.routeColor ?? departure.routeColor,
        routeTextColor: leg.routeTextColor ?? departure.routeTextColor,
      ),
      geometry: leg.geometry,
      stops: <TransitStop>[leg.from, ...leg.intermediateStops, leg.to],
    );
  }

  /// Opens the detail for one departure's train: loads its full shape and stop
  /// list and draws **only** that line on the map.
  Future<void> openTrip(TransitStopDeparture departure) async {
    final String tripId = departure.tripId?.trim() ?? '';
    if (tripId.isEmpty) {
      return;
    }
    state = state.copyWith(
      selectedDeparture: departure,
      tripLoading: true,
      clearTrip: false,
      tripError: null,
    );
    final Result<TransitItinerary> result = await ref.read(
      requestTransitTripProvider,
    )(tripId);
    if (!ref.mounted) {
      return;
    }
    final TransitStopDeparture? current = state.selectedDeparture;
    if (current == null || (current.tripId ?? '') != tripId) {
      return; // superseded by another tap / closed
    }
    final TransitStopLine? line = _lineFromItinerary(
      result.valueOrNull,
      departure,
    );
    if (line == null) {
      state = state.copyWith(
        tripLoading: false,
        tripError: result.errorOrNull ?? const NotFoundException('No train'),
      );
      return;
    }
    state = state.copyWith(tripDetail: line, tripLoading: false);
    await _drawLines(only: line);
  }

  /// Opens the train detail by trip id, looking the departure up in the loaded
  /// rows.
  Future<void> openTripById(String tripId) async {
    final String id = tripId.trim();
    if (id.isEmpty) {
      return;
    }
    for (final TransitStopDeparture departure in state.departures) {
      if ((departure.tripId ?? '').trim() == id) {
        await openTrip(departure);
        return;
      }
    }
  }

  /// Closes the train detail and restores the stop's lines on the map.
  void closeTrip() {
    if (!state.hasTripDetail) {
      return;
    }
    state = state.copyWith(clearTrip: true);
    unawaited(_drawLines());
  }

  bool get _mapIsFree =>
      ref.read(routeControllerProvider).status == RouteStatus.idle;

  Future<void> _drawLines({TransitStopLine? only}) async {
    if (!_mapIsFree) {
      return; // a planned route owns the map lines
    }
    final List<TransitStopLine> lines = only != null
        ? <TransitStopLine>[only]
        : state.lines;
    final MapService map = ref.read(mapServiceProvider);
    final List<RouteLine> routeLines = <RouteLine>[
      for (final TransitStopLine line in lines)
        if (line.geometry.length >= 2)
          RouteLine(
            points: line.geometry,
            color: line.route.displayColor,
            width: only != null ? 8 : 6,
            primary: only != null,
          ),
    ];

    final Map<String, TransitStopMarker> byPlace =
        <String, TransitStopMarker>{};
    for (final TransitStopLine line in lines) {
      final int color = line.route.displayColor;
      for (final TransitStop stop in line.stops) {
        final LatLon? position = stop.position;
        if (position == null) {
          continue;
        }
        byPlace.putIfAbsent(
          _markerKey(position),
          () => TransitStopMarker(
            id: _markerKey(position),
            position: position,
            emphasis: TransitStopEmphasis.pass,
            color: color,
          ),
        );
      }
    }
    // The tapped stop is drawn larger, in the first line's colour.
    final LatLon? stopPosition = state.position;
    if (stopPosition != null) {
      byPlace[_markerKey(stopPosition)] = TransitStopMarker(
        id: _markerKey(stopPosition),
        position: stopPosition,
        emphasis: TransitStopEmphasis.board,
        color: lines.isEmpty ? _defaultColor : lines.first.route.displayColor,
      );
    }

    _drewMap = true;
    unawaited(map.setRouteLines(routeLines));
    unawaited(
      map.setTransitStopMarkers(
        List<TransitStopMarker>.unmodifiable(byPlace.values),
      ),
    );
  }

  /// Clears the lines this board drew, unless a planned route now owns them (so
  /// opening directions never leaves the map blank).
  Future<void> _clearMap() async {
    if (!_drewMap) {
      return;
    }
    _drewMap = false;
    if (!_mapIsFree) {
      return;
    }
    final MapService map = ref.read(mapServiceProvider);
    unawaited(map.setRouteLines(const <RouteLine>[]));
    unawaited(map.setTransitStopMarkers(const <TransitStopMarker>[]));
  }

  static String _markerKey(LatLon position) =>
      '${position.latitude.toStringAsFixed(5)},'
      '${position.longitude.toStringAsFixed(5)}';

  static String _rowKey(TransitStopDeparture row) =>
      '${row.tripId ?? ''}|${row.routeShortName ?? ''}|'
      '${row.displayDeparture.millisecondsSinceEpoch}';

  /// The distinct-line key for a departure (label + mode), matching the line
  /// chips so one line is drawn once.
  static String _lineKey(TransitStopDeparture departure) =>
      '${departure.routeShortName ?? departure.routeLongName ?? ''}'
      '|${departure.mode.name}';
}

final NotifierProvider<TransitStopBoardController, TransitStopBoardState>
transitStopBoardProvider =
    NotifierProvider<TransitStopBoardController, TransitStopBoardState>(
      TransitStopBoardController.new,
    );
