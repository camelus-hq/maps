import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';

/// Straight north-south geometry with [samples] points, so distances are
/// predictable.
List<LatLon> _line(double latFrom, double latTo, {int samples = 9}) {
  return <LatLon>[
    for (int i = 0; i < samples; i++)
      LatLon(latFrom + (latTo - latFrom) * (i / (samples - 1)), 13),
  ];
}

void main() {
  final DateTime base = DateTime.utc(2026, 1, 1, 9);

  TransitItinerary itinerary() {
    final List<LatLon> walk = _line(52.0, 52.01);
    final List<LatLon> ride = _line(52.01, 52.05);
    final List<LatLon> walk2 = _line(52.05, 52.06);
    return TransitItinerary(
      startTime: base,
      endTime: base.add(const Duration(minutes: 30)),
      legs: <TransitLeg>[
        TransitLeg(
          mode: TransitMode.walk,
          from: const TransitStop(name: 'Start', position: LatLon(52.0, 13)),
          to: const TransitStop(
            name: 'Stop A',
            id: 'a',
            position: LatLon(52.01, 13),
          ),
          startTime: base,
          endTime: base.add(const Duration(minutes: 5)),
          duration: const Duration(minutes: 5),
          geometry: walk,
        ),
        TransitLeg(
          mode: TransitMode.subway,
          from: const TransitStop(
            name: 'Stop A',
            id: 'a',
            position: LatLon(52.01, 13),
            track: '1',
          ),
          to: const TransitStop(
            name: 'Stop B',
            id: 'b',
            position: LatLon(52.05, 13),
            track: '2',
          ),
          startTime: base.add(const Duration(minutes: 6)),
          endTime: base.add(const Duration(minutes: 25)),
          duration: const Duration(minutes: 19),
          routeShortName: 'U5',
          routeColor: 0xFF6A4C93,
          geometry: ride,
          intermediateStops: <TransitStop>[
            const TransitStop(name: 'Mid', position: LatLon(52.03, 13)),
          ],
        ),
        TransitLeg(
          mode: TransitMode.walk,
          from: const TransitStop(
            name: 'Stop B',
            id: 'b',
            position: LatLon(52.05, 13),
          ),
          to: const TransitStop(name: 'End', position: LatLon(52.06, 13)),
          startTime: base.add(const Duration(minutes: 25)),
          endTime: base.add(const Duration(minutes: 30)),
          duration: const Duration(minutes: 5),
          geometry: walk2,
        ),
      ],
    );
  }

  test('walking toward the first ride reports the ride to board', () {
    final TransitItinerary it = itinerary();
    final TransitProgress p = it.progressAt(0);
    expect(p.phase, TransitPhase.walk);
    expect(p.legIndex, 0);
    expect(p.ride?.lineLabel, 'U5');
    expect(p.onBoard, isFalse);
  });

  test('on board reports the ride and the stops left', () {
    final TransitItinerary it = itinerary();
    final double walkLength = it.legs[0].geometry.first.distanceTo(
      it.legs[0].geometry.last,
    );
    // Halfway along the ride: one intermediate stop + the alight remain.
    final double rideLength = it.legs[1].geometry.first.distanceTo(
      it.legs[1].geometry.last,
    );
    final TransitProgress early = it.progressAt(walkLength + rideLength * 0.2);
    expect(early.phase, TransitPhase.ride);
    expect(early.legIndex, 1);
    expect(early.ride, same(it.legs[1]));
    expect(early.stopsRemaining, 2);

    // Past the intermediate stop: only the alight remains.
    final TransitProgress late = it.progressAt(walkLength + rideLength * 0.8);
    expect(late.stopsRemaining, 1);
    expect(late.fractionInLeg, greaterThan(0.5));
  });

  test('the final walk has no ride and the end reads as arrived', () {
    final TransitItinerary it = itinerary();
    final double walk1 = it.legs[0].geometry.first.distanceTo(
      it.legs[0].geometry.last,
    );
    final double ride = it.legs[1].geometry.first.distanceTo(
      it.legs[1].geometry.last,
    );
    final TransitProgress walking = it.progressAt(walk1 + ride + 200);
    expect(walking.phase, TransitPhase.walk);
    expect(walking.ride, isNull);
    final TransitProgress done = it.progressAt(1e9);
    expect(done.phase, TransitPhase.arrived);
  });

  test('degenerate journeys never throw', () {
    final TransitItinerary empty = TransitItinerary(
      legs: const <TransitLeg>[],
      startTime: _epoch,
      endTime: _epoch,
    );
    expect(empty.progressAt(0).phase, TransitPhase.arrived);
    expect(itinerary().progressAt(double.nan).phase, TransitPhase.walk);
  });
}

final DateTime _epoch = DateTime.utc(2026);
