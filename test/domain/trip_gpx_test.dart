import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';
import 'package:openmaps/domain/usecases/trip_gpx.dart';

void main() {
  Trip trip({
    String? destination = 'Café & Co <Berlin>',
    List<LatLon> track = const <LatLon>[
      LatLon(52.5200, 13.4050),
      LatLon(52.5301, 13.4234),
    ],
  }) => Trip(
    id: 'trip-1',
    startedAt: DateTime.utc(2026, 5, 1, 9),
    endedAt: DateTime.utc(2026, 5, 1, 9, 30),
    mode: TravelMode.cycle,
    distanceMeters: 4200,
    destinationName: destination,
    track: track,
  );

  test('encodes a GPX trk with one trkpt per point', () {
    final String gpx = TripGpx.encode(trip());
    expect(gpx, startsWith('<?xml version="1.0" encoding="UTF-8"?>'));
    expect(gpx, contains('<gpx version="1.1"'));
    expect(gpx, contains('<trk>'));
    expect(gpx, contains('<type>cycle</type>'));
    expect(gpx, contains('<trkpt lat="52.520000" lon="13.405000"/>'));
    expect(gpx, contains('<trkpt lat="52.530100" lon="13.423400"/>'));
    expect(
      '<trkpt'.allMatches(gpx).length,
      2,
      reason: 'one trkpt per recorded point',
    );
    expect(gpx, endsWith('</gpx>\n'));
  });

  test('escapes XML-hostile names', () {
    final String gpx = TripGpx.encode(trip());
    expect(gpx, contains('Café &amp; Co &lt;Berlin&gt;'));
    expect(gpx, isNot(contains('<Berlin>')));
  });

  test('an empty track produces a valid, empty trkseg', () {
    final String gpx = TripGpx.encode(
      Trip(
        id: 'trip-2',
        startedAt: DateTime.utc(2026, 1, 1),
        endedAt: DateTime.utc(2026, 1, 1),
        mode: TravelMode.walk,
        distanceMeters: 0,
        track: const <LatLon>[],
      ),
    );
    expect(gpx, contains('<trkseg>'));
    expect(gpx, contains('</trkseg>'));
    expect('<trkpt'.allMatches(gpx), isEmpty);
  });
}
