import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/transit.dart';
import 'usecases.dart';

enum DeparturesStatus { idle, loading, data, error }

/// The "Departures" board state: the stop whose next departures are being
/// shown and the loaded rows (or the failure).
class TransitDeparturesState {
  const TransitDeparturesState({
    this.status = DeparturesStatus.idle,
    this.stopId,
    this.stopName,
    this.departures = const <TransitStopDeparture>[],
    this.error,
  });

  final DeparturesStatus status;
  final String? stopId;

  /// The stop's display name (falls back to the id).
  final String? stopName;

  final List<TransitStopDeparture> departures;
  final AppException? error;

  /// Whether the board should be visible.
  bool get isOpen => status != DeparturesStatus.idle;
}

/// Loads a stop's next departures for the departures board (opened by tapping a
/// station on a journey timeline). Guards against a stale response arriving
/// after the board was closed or another stop opened.
class TransitDeparturesController extends Notifier<TransitDeparturesState> {
  /// How recently a departure may have left and still be listed, so the board
  /// also shows a just-missed (or running-late) train.
  static const Duration pastWindow = Duration(minutes: 10);

  /// How many already-left departures to keep above "now" so the board opens
  /// with the current time in view (the newest of them first).
  static const int maxPastDepartures = 2;

  int _requestId = 0;

  @override
  TransitDeparturesState build() => const TransitDeparturesState();

  Future<void> open({required String stopId, String? stopName}) async {
    final String id = stopId.trim();
    if (id.isEmpty) {
      return;
    }
    state = TransitDeparturesState(
      status: DeparturesStatus.loading,
      stopId: id,
      stopName: (stopName?.trim().isEmpty ?? true) ? id : stopName,
    );
    await _load();
  }

  Future<void> retry() async {
    if (state.stopId == null) {
      return;
    }
    state = TransitDeparturesState(
      status: DeparturesStatus.loading,
      stopId: state.stopId,
      stopName: state.stopName,
    );
    await _load();
  }

  Future<void> _load() async {
    final String? id = state.stopId;
    if (id == null) {
      return;
    }
    final int request = ++_requestId;
    // Ask from a little in the past so a just-missed or running-late departure
    // is still shown.
    final DateTime earliest = DateTime.now().subtract(pastWindow);
    final Result<List<TransitStopDeparture>> result = await ref.read(
      requestStopDeparturesProvider,
    )(TransitDeparturesQuery(stopId: id, time: earliest, limit: 16));
    // The board may have been closed (or another stop opened) while the request
    // was in flight — never resurrect a stale board.
    if (request != _requestId) {
      return;
    }
    result.fold(
      ok: (List<TransitStopDeparture> departures) =>
          state = TransitDeparturesState(
            status: DeparturesStatus.data,
            stopId: id,
            stopName: state.stopName,
            departures: _visible(departures, earliest),
          ),
      err: (AppException error) => state = TransitDeparturesState(
        status: DeparturesStatus.error,
        stopId: id,
        stopName: state.stopName,
        error: error,
      ),
    );
  }

  /// The departures to show: everything from [earliest] onward, but only the
  /// [maxPastDepartures] most recent already-left ones — so the list opens with
  /// "now" in view.
  static List<TransitStopDeparture> _visible(
    List<TransitStopDeparture> departures,
    DateTime earliest,
  ) {
    final DateTime now = DateTime.now();
    final List<TransitStopDeparture> past = <TransitStopDeparture>[];
    final List<TransitStopDeparture> upcoming = <TransitStopDeparture>[];
    for (final TransitStopDeparture departure in departures) {
      final DateTime when = departure.displayDeparture;
      if (when.isBefore(earliest)) {
        continue;
      }
      if (when.isBefore(now)) {
        past.add(departure);
      } else {
        upcoming.add(departure);
      }
    }
    final List<TransitStopDeparture> recent = past.length <= maxPastDepartures
        ? past
        : past.sublist(past.length - maxPastDepartures);
    return <TransitStopDeparture>[...recent, ...upcoming];
  }

  void close() {
    _requestId++;
    state = const TransitDeparturesState();
  }
}

final NotifierProvider<TransitDeparturesController, TransitDeparturesState>
transitDeparturesProvider =
    NotifierProvider<TransitDeparturesController, TransitDeparturesState>(
      TransitDeparturesController.new,
    );
