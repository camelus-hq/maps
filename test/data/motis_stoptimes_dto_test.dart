import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/motis_stoptimes_dto.dart';
import 'package:openmaps/domain/entities/transit.dart';

Map<String, Object?> sampleStoptimes() => <String, Object?>{
  'stopTimes': <Object?>[
    <String, Object?>{
      'mode': 'METRO',
      'realTime': true,
      'headsign': 'S+U Gesundbrunnen Bhf',
      'agencyName': 'S-Bahn Berlin GmbH',
      'routeShortName': 'S41',
      'routeLongName': '',
      'routeColor': 'cb6418',
      'routeTextColor': 'ffffff',
      'tripId': 'trip-1',
      'cancelled': false,
      'wheelchairAccessible': 'ACCESSIBLE',
      'bikesAllowed': true,
      'place': <String, Object?>{
        'name': 'S Messe Nord/ZOB (Berlin)',
        'stopId': 'de:1',
        'track': '2',
        'scheduledTrack': '1',
        'departure': '2026-11-09T10:09:00Z',
        'scheduledDeparture': '2026-11-09T10:05:00Z',
      },
    },
    <String, Object?>{
      'mode': 'BUS',
      'realTime': false,
      'headsign': 'Kladow, Gutsstr.',
      'routeShortName': 'X34',
      'cancelled': true,
      'place': <String, Object?>{
        'name': 'S Messe Nord (Berlin)',
        'stopId': 'de:2',
        'departure': '2026-11-09T10:12:00Z',
        'scheduledDeparture': '2026-11-09T10:12:00Z',
      },
    },
  ],
};

void main() {
  test('maps a MOTIS stop-times response into departures', () {
    final List<TransitStopDeparture> departures =
        MotisStoptimesDto.departuresFromResponse(sampleStoptimes());
    expect(departures, hasLength(2));

    final TransitStopDeparture first = departures.first;
    expect(first.mode, TransitMode.metro);
    expect(first.lineLabel, 'S41');
    expect(first.headsign, 'S+U Gesundbrunnen Bhf');
    expect(first.displayTrack, '2');
    expect(first.hasTrack, isTrue);
    expect(first.realTime, isTrue);
    expect(first.cancelled, isFalse);
    expect(first.wheelchairAccessible, isTrue);
    expect(first.bikesAllowed, isTrue);
    expect(first.displayColor, 0xFFCB6418);
    expect(first.delay, const Duration(minutes: 4));

    final TransitStopDeparture second = departures[1];
    expect(second.lineLabel, 'X34');
    expect(second.cancelled, isTrue);
    expect(second.delay, isNull);
  });

  test('hostile payloads yield no departures and never throw', () {
    expect(MotisStoptimesDto.departuresFromResponse(null), isEmpty);
    expect(MotisStoptimesDto.departuresFromResponse('nope'), isEmpty);
    expect(
      MotisStoptimesDto.departuresFromResponse(<String, Object?>{}),
      isEmpty,
    );
    expect(
      MotisStoptimesDto.departuresFromResponse(<String, Object?>{
        'stopTimes': 'not a list',
      }),
      isEmpty,
    );
    expect(
      MotisStoptimesDto.departuresFromResponse(<String, Object?>{
        'stopTimes': <Object?>[
          null,
          42,
          <String, Object?>{'mode': 'BUS'}, // no place/departure
          <String, Object?>{'place': 'x'},
        ],
      }),
      isEmpty,
    );
  });
}
