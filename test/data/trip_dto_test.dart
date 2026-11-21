import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/trip_dto.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';

void main() {
  Trip trip({
    String id = 'trip-1',
    List<LatLon> track = const <LatLon>[
      LatLon(52.52, 13.40),
      LatLon(52.53, 13.42),
    ],
  }) => Trip(
    id: id,
    startedAt: DateTime.utc(2026, 5, 1, 9),
    endedAt: DateTime.utc(2026, 5, 1, 9, 30),
    mode: TravelMode.cycle,
    distanceMeters: 4200,
    originName: 'Home',
    destinationName: 'Office',
    track: track,
  );

  test('a trip round-trips through JSON', () {
    final Trip original = trip();
    final Trip? decoded = TripDto.fromJson(TripDto.toJson(original));
    expect(decoded, isNotNull);
    final Trip value = decoded!;
    expect(value.id, original.id);
    expect(value.startedAt, original.startedAt);
    expect(value.endedAt, original.endedAt);
    expect(value.mode, TravelMode.cycle);
    expect(value.distanceMeters, original.distanceMeters);
    expect(value.originName, 'Home');
    expect(value.destinationName, 'Office');
    expect(value.track, original.track);
    expect(value.duration, const Duration(minutes: 30));
  });

  test('a list round-trips and keeps order', () {
    final List<Trip> trips = <Trip>[trip(id: 'a'), trip(id: 'b')];
    final List<Trip> decoded = TripDto.decodeList(TripDto.encodeList(trips));
    expect(decoded.map((Trip t) => t.id), <String>['a', 'b']);
  });

  test('malformed entries are dropped, not thrown', () {
    expect(TripDto.fromJson(null), isNull);
    expect(TripDto.fromJson('nope'), isNull);
    expect(TripDto.fromJson(<String, Object?>{}), isNull);
    expect(TripDto.fromJson(<String, Object?>{'id': 'x'}), isNull);
    expect(
      TripDto.fromJson(<String, Object?>{
        'id': 'x',
        'startedAt': 'not a number',
      }),
      isNull,
    );
    expect(
      TripDto.fromJson(<String, Object?>{
        'id': 'x',
        'startedAt': 1,
        'mode': 'teleport',
      }),
      isNull,
    );
  });

  test('hostile track points and names are bounded and skipped', () {
    final Trip? decoded = TripDto.fromJson(<String, Object?>{
      'id': 'x',
      'startedAt': 1000,
      'mode': 'walk',
      'origin': '   ',
      'destination': 'A' * 500,
      'track': <Object?>[
        <Object?>[52.5, 13.4],
        <Object?>[999, 13.4], // out of range
        <Object?>[52.5], // too short
        'nope',
        <Object?>[52.6, 13.5],
      ],
    });
    expect(decoded, isNotNull);
    expect(decoded!.originName, isNull);
    expect(decoded.destinationName, hasLength(TripDto.maxNameLength));
    expect(decoded.track, <LatLon>[
      const LatLon(52.5, 13.4),
      const LatLon(52.6, 13.5),
    ]);
  });

  test('an ended-at before started-at is clamped, distance floored', () {
    final Trip? decoded = TripDto.fromJson(<String, Object?>{
      'id': 'x',
      'startedAt': 2000,
      'endedAt': 1000,
      'mode': 'drive',
      'distanceMeters': -5,
      'track': <Object?>[],
    });
    expect(decoded, isNotNull);
    expect(decoded!.endedAt, decoded.startedAt);
    expect(decoded.distanceMeters, 0);
  });

  test('a corrupt list decodes to empty', () {
    expect(TripDto.decodeList(null), isEmpty);
    expect(TripDto.decodeList('{ not json'), isEmpty);
    expect(TripDto.decodeList('{"a":1}'), isEmpty);
  });
}
