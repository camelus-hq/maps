import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/motis_plan_dto.dart';
import 'package:openmaps/domain/entities/transit.dart';

/// A synthetic MOTIS `/plan` response in the provider's own shape (never a
/// captured real payload). Times are UTC, `legGeometry` uses precision 7.
Map<String, Object?> sampleResponse() => <String, Object?>{
  'itineraries': <Object?>[
    <String, Object?>{
      'id': 'itin-1',
      'startTime': '2026-05-01T09:00:00Z',
      'endTime': '2026-05-01T09:23:00Z',
      'transfers': 0,
      'legs': <Object?>[
        <String, Object?>{
          'mode': 'WALK',
          'startTime': '2026-05-01T09:00:00Z',
          'endTime': '2026-05-01T09:07:00Z',
          'duration': 420,
          'distance': 461,
          'from': <String, Object?>{
            'name': 'START',
            'lat': 52.517,
            'lon': 13.389,
          },
          'to': <String, Object?>{
            'name': 'Station',
            'lat': 52.5205,
            'lon': 13.3872,
            'track': '6',
            'scheduledTrack': '6',
          },
          'legGeometry': <String, Object?>{
            'points': 'usyth^cw~j~F{Ed@',
            'precision': 7,
            'length': 2,
          },
        },
        <String, Object?>{
          'mode': 'SUBWAY',
          'routeShortName': 'U5',
          'routeLongName': '',
          'headsign': 'Hauptbahnhof',
          'agencyName': 'BVG',
          'routeColor': '7A5C1E',
          'routeTextColor': 'ffffff',
          'realTime': true,
          'startTime': '2026-05-01T09:07:00Z',
          'scheduledStartTime': '2026-05-01T09:06:00Z',
          'endTime': '2026-05-01T09:19:00Z',
          'scheduledEndTime': '2026-05-01T09:19:00Z',
          'duration': 720,
          'distance': 5400,
          'from': <String, Object?>{
            'name': 'Station',
            'lat': 52.5205,
            'lon': 13.3872,
            'track': '1',
          },
          'to': <String, Object?>{
            'name': 'Hauptbahnhof',
            'lat': 52.5252,
            'lon': 13.3693,
            'track': '16',
          },
          'intermediateStops': <Object?>[
            <String, Object?>{
              'name': 'Friedrichstr',
              'lat': 52.52,
              'lon': 13.38,
              'track': '3',
            },
          ],
          'legGeometry': <String, Object?>{
            'points': 'usyth^cw~j~F{Ed@',
            'precision': 7,
            'length': 2,
          },
        },
        <String, Object?>{
          'mode': 'WALK',
          'startTime': '2026-05-01T09:19:00Z',
          'endTime': '2026-05-01T09:23:00Z',
          'duration': 240,
          'from': <String, Object?>{
            'name': 'Hauptbahnhof',
            'lat': 52.5252,
            'lon': 13.3693,
          },
          'to': <String, Object?>{'name': 'DEST', 'lat': 52.524, 'lon': 13.37},
        },
      ],
    },
  ],
};

void main() {
  test('maps a MOTIS plan into one itinerary with legs and transfers', () {
    final List<TransitItinerary> itineraries =
        MotisPlanDto.itinerariesFromResponse(sampleResponse());

    expect(itineraries, hasLength(1));
    final TransitItinerary itinerary = itineraries.first;
    expect(itinerary.id, 'itin-1');
    expect(itinerary.legs, hasLength(3));
    expect(itinerary.duration, const Duration(minutes: 23));
    expect(itinerary.rides, hasLength(1));
    expect(itinerary.transfers, 0);
    expect(itinerary.walkingMeters, 461);
    // Two legs carry geometry (2 points each); the last walk has none.
    expect(itinerary.geometry, hasLength(4));
    expect(itinerary.agencies, <String>['BVG']);
  });

  test('maps the transit leg: line, colours, realtime delay and tracks', () {
    final TransitLeg leg = MotisPlanDto.itinerariesFromResponse(
      sampleResponse(),
    ).first.legs[1];

    expect(leg.mode, TransitMode.subway);
    expect(leg.isTransit, isTrue);
    expect(leg.lineLabel, 'U5');
    expect(leg.headsign, 'Hauptbahnhof');
    expect(leg.agencyName, 'BVG');
    expect(leg.routeColor, 0xFF7A5C1E);
    expect(leg.routeTextColor, 0xFFFFFFFF);
    expect(leg.realTime, isTrue);
    // Real 09:07 vs scheduled 09:06 → one minute late.
    expect(leg.departureDelay, const Duration(minutes: 1));
    expect(leg.arrivalDelay, Duration.zero);
    // The platform/track is present at both ends of the ride and at the stop
    // passed through.
    expect(leg.from.displayTrack, '1');
    expect(leg.from.hasTrack, isTrue);
    expect(leg.to.displayTrack, '16');
    expect(leg.intermediateStops, hasLength(1));
    expect(leg.intermediateStops.first.displayTrack, '3');
  });

  test('a walk leg is not transit and carries no line', () {
    final TransitLeg leg = MotisPlanDto.itinerariesFromResponse(
      sampleResponse(),
    ).first.legs.first;
    expect(leg.mode, TransitMode.walk);
    expect(leg.isWalk, isTrue);
    expect(leg.isTransit, isFalse);
  });

  test('an empty itinerary list decodes to an empty list', () {
    expect(MotisPlanDto.itinerariesFromResponse(<String, Object?>{}), isEmpty);
    expect(
      MotisPlanDto.itinerariesFromResponse(<String, Object?>{
        'itineraries': <Object?>[],
      }),
      isEmpty,
    );
  });

  test('itineraries without usable legs are skipped', () {
    final List<TransitItinerary> result = MotisPlanDto.itinerariesFromResponse(
      <String, Object?>{
        'itineraries': <Object?>[
          <String, Object?>{'legs': <Object?>[]},
          <String, Object?>{
            'legs': <Object?>[
              <String, Object?>{'mode': 'WALK'},
            ],
          },
        ],
      },
    );
    expect(result, isEmpty);
  });

  test('an unknown mode degrades to "other" without throwing', () {
    expect(transitModeFromMotis('HYPERLOOP'), TransitMode.other);
    expect(transitModeFromMotis(null), TransitMode.other);
    expect(transitModeFromMotis('suburban'), TransitMode.suburbanRail);
  });

  test('mode groups map to MOTIS modes for the preference filter', () {
    expect(TransitModeGroup.bus.modes, contains(TransitMode.bus));
    expect(TransitModeGroup.train.modes, contains(TransitMode.suburbanRail));
    expect(TransitModeGroup.subway.modes, contains(TransitMode.metro));
  });
}
