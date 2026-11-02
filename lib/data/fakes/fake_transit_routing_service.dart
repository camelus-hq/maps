import '../../core/errors/app_exception.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/transit.dart';
import '../../domain/ports/transit_routing_service.dart';

/// Keyless [TransitRoutingService] for tests and the no-key developer run.
///
/// It never touches the network: it lays straight lines between the waypoints
/// and invents two plausible journeys (one with a change, one with realtime
/// information and a platform/track) so every transit screen has content to
/// render.
class FakeTransitRoutingService implements TransitRoutingService {
  FakeTransitRoutingService({this.now, this.numItineraries = 2});

  /// The clock to build sample times from; defaults to the current time.
  final DateTime? now;
  final int numItineraries;

  static const int _samplesPerSegment = 8;

  @override
  Future<List<TransitItinerary>> plan(TransitQuery query) async {
    final List<LatLon> waypoints = query.waypoints;
    if (waypoints.length < 2) {
      throw const ValidationException('A journey needs at least two waypoints');
    }
    final DateTime base = (query.time ?? now ?? DateTime.now()).toUtc();
    final List<TransitItinerary> all = _build(query, waypoints, base);
    final int requested = query.numItineraries < 1 ? 1 : query.numItineraries;
    final int limit = requested < numItineraries ? requested : numItineraries;
    return List<TransitItinerary>.unmodifiable(
      all.take(limit).toList(growable: false),
    );
  }

  List<TransitItinerary> _build(
    TransitQuery query,
    List<LatLon> waypoints,
    DateTime base,
  ) {
    // For a multi-stop journey, present a single chained journey (matching the
    // real adapter's behaviour) so the UI shows every requested stop.
    if (waypoints.length > 2) {
      return <TransitItinerary>[_chained(waypoints, base)];
    }
    final LatLon origin = waypoints.first;
    final LatLon destination = waypoints.last;
    final LatLon stopA = _along(origin, destination, 0.25);
    final LatLon stopB = _along(origin, destination, 0.75);

    // Journey 1: one ride with a realtime delay and a platform.
    final TransitItinerary first = TransitItinerary(
      id: 'fake-itinerary-1',
      startTime: base,
      endTime: base.add(const Duration(minutes: 19)),
      legs: <TransitLeg>[
        TransitLeg(
          mode: TransitMode.walk,
          from: TransitStop(name: 'Start', position: origin),
          to: TransitStop(name: 'North Street', position: stopA),
          startTime: base,
          endTime: base.add(const Duration(minutes: 4)),
          duration: const Duration(minutes: 4),
          distanceMeters: origin.distanceTo(stopA),
          geometry: _line(origin, stopA),
        ),
        TransitLeg(
          mode: TransitMode.tram,
          from: TransitStop(
            name: 'North Street',
            id: 'fake:stop-a',
            position: stopA,
            track: '1',
          ),
          to: TransitStop(
            name: 'Market Square',
            id: 'fake:stop-b',
            position: stopB,
            track: '2',
          ),
          startTime: base.add(const Duration(minutes: 5)),
          scheduledStartTime: base.add(const Duration(minutes: 4)),
          endTime: base.add(const Duration(minutes: 16)),
          scheduledEndTime: base.add(const Duration(minutes: 16)),
          duration: const Duration(minutes: 12),
          distanceMeters: stopA.distanceTo(stopB),
          geometry: _line(stopA, stopB),
          routeShortName: 'M2',
          headsign: 'Market Square',
          agencyName: 'City Transit',
          routeColor: 0xFF1F6FB2,
          realTime: true,
          intermediateStops: <TransitStop>[
            TransitStop(
              name: 'Harbour Road',
              position: _along(stopA, stopB, 0.5),
            ),
          ],
        ),
        TransitLeg(
          mode: TransitMode.walk,
          from: TransitStop(name: 'Market Square', position: stopB),
          to: TransitStop(name: 'Destination', position: destination),
          startTime: base.add(const Duration(minutes: 16)),
          endTime: base.add(const Duration(minutes: 19)),
          duration: const Duration(minutes: 3),
          distanceMeters: stopB.distanceTo(destination),
          geometry: _line(stopB, destination),
        ),
      ],
    );

    // Journey 2: a change between two rides and a platform at the transfer.
    final LatLon transfer = _along(origin, destination, 0.55);
    final TransitItinerary second = TransitItinerary(
      id: 'fake-itinerary-2',
      startTime: base.add(const Duration(minutes: 6)),
      endTime: base.add(const Duration(minutes: 28)),
      legs: <TransitLeg>[
        TransitLeg(
          mode: TransitMode.walk,
          from: TransitStop(name: 'Start', position: origin),
          to: TransitStop(name: 'Central Station', position: stopA),
          startTime: base.add(const Duration(minutes: 6)),
          endTime: base.add(const Duration(minutes: 9)),
          duration: const Duration(minutes: 3),
          distanceMeters: origin.distanceTo(stopA),
          geometry: _line(origin, stopA),
        ),
        TransitLeg(
          mode: TransitMode.subway,
          from: TransitStop(
            name: 'Central Station',
            id: 'fake:stop-a',
            position: stopA,
            track: '3',
          ),
          to: TransitStop(
            name: 'Transfer',
            id: 'fake:transfer',
            position: transfer,
            track: '1',
          ),
          startTime: base.add(const Duration(minutes: 9)),
          endTime: base.add(const Duration(minutes: 20)),
          duration: const Duration(minutes: 11),
          distanceMeters: stopA.distanceTo(transfer),
          geometry: _line(stopA, transfer),
          routeShortName: 'U5',
          headsign: 'Transfer',
          agencyName: 'City Transit',
          routeColor: 0xFF6A4C93,
        ),
        TransitLeg(
          mode: TransitMode.walk,
          from: TransitStop(name: 'Transfer', position: transfer),
          to: TransitStop(name: 'Transfer', position: transfer),
          startTime: base.add(const Duration(minutes: 20)),
          endTime: base.add(const Duration(minutes: 24)),
          duration: const Duration(minutes: 4),
          distanceMeters: 260,
          geometry: _line(transfer, _along(transfer, destination, 0.2)),
        ),
        TransitLeg(
          mode: TransitMode.suburbanRail,
          from: TransitStop(
            name: 'Transfer',
            id: 'fake:transfer',
            position: transfer,
            track: '7',
          ),
          to: TransitStop(
            name: 'Destination',
            id: 'fake:stop-b',
            position: destination,
            track: '',
          ),
          startTime: base.add(const Duration(minutes: 24)),
          endTime: base.add(const Duration(minutes: 28)),
          duration: const Duration(minutes: 4),
          distanceMeters: transfer.distanceTo(destination),
          geometry: _line(transfer, destination),
          routeShortName: 'S1',
          headsign: 'Destination',
          agencyName: 'Regional Rail',
          routeColor: 0xFFB07A1F,
        ),
      ],
    );

    return <TransitItinerary>[first, second];
  }

  /// A single chained journey through every waypoint (multi-stop preview).
  TransitItinerary _chained(List<LatLon> waypoints, DateTime base) {
    final List<TransitLeg> legs = <TransitLeg>[];
    DateTime cursor = base;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final LatLon from = waypoints[i];
      final LatLon to = waypoints[i + 1];
      final int walkMinutes = i == 0 ? 3 : 2;
      legs.add(
        TransitLeg(
          mode: TransitMode.walk,
          from: TransitStop(name: i == 0 ? 'Start' : 'Stop ${i + 1}'),
          to: TransitStop(name: 'Board ${i + 1}'),
          startTime: cursor,
          endTime: cursor.add(Duration(minutes: walkMinutes)),
          duration: Duration(minutes: walkMinutes),
          distanceMeters: from.distanceTo(to) * 0.2,
          geometry: _line(from, _along(from, to, 0.2)),
        ),
      );
      cursor = cursor.add(Duration(minutes: walkMinutes));
      final int rideMinutes = 8 + i;
      legs.add(
        TransitLeg(
          mode: TransitMode.bus,
          from: TransitStop(name: 'Board ${i + 1}', track: '${i + 1}'),
          to: TransitStop(name: 'Stop ${i + 2}', track: '${i + 2}'),
          startTime: cursor,
          endTime: cursor.add(Duration(minutes: rideMinutes)),
          duration: Duration(minutes: rideMinutes),
          distanceMeters: from.distanceTo(to) * 0.7,
          geometry: _line(_along(from, to, 0.2), to),
          routeShortName: 'Bus ${100 + i}',
          headsign: 'Stop ${i + 2}',
          agencyName: 'City Transit',
          routeColor: 0xFF1F6FB2,
        ),
      );
      cursor = cursor.add(Duration(minutes: rideMinutes));
    }
    return TransitItinerary(
      id: 'fake-itinerary-chained',
      startTime: base,
      endTime: cursor,
      legs: List<TransitLeg>.unmodifiable(legs),
    );
  }

  static LatLon _along(LatLon from, LatLon to, double t) => LatLon(
    from.latitude + (to.latitude - from.latitude) * t,
    from.longitude + (to.longitude - from.longitude) * t,
  );

  static List<LatLon> _line(LatLon from, LatLon to) => <LatLon>[
    for (int s = 0; s <= _samplesPerSegment; s++)
      _along(from, to, s / _samplesPerSegment),
  ];
}
