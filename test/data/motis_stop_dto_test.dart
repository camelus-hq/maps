import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/motis_stop_dto.dart';
import 'package:openmaps/domain/entities/transit.dart';

void main() {
  test('maps a stop and de-duplicates its lines', () {
    final TransitStopInfo? info = MotisStopDto.stopInfoFromResponse(
      <String, Object?>{
        'place': <String, Object?>{
          'name': 'S+U Alexanderplatz',
          'stopId': 'de:1',
          'lat': 52.5216,
          'lon': 13.41114,
        },
        'routes': <Object?>[
          <String, Object?>{
            'routeId': 's41',
            'mode': 'SUBURBAN',
            'routeShortName': 'S41',
            'routeColor': 'cb6418',
          },
          <String, Object?>{
            'routeId': 's41-other-network',
            'mode': 'SUBURBAN',
            'routeShortName': 'S41',
            'routeColor': 'cb6418',
          },
          <String, Object?>{'mode': 'SUBWAY', 'routeShortName': 'U8'},
        ],
      },
    );

    expect(info, isNotNull);
    expect(info!.stopId, 'de:1');
    expect(info.name, 'S+U Alexanderplatz');
    expect(info.position?.latitude, closeTo(52.5216, 1e-6));
    expect(info.routes, hasLength(2));
    expect(info.routes.first.lineLabel, 'S41');
    expect(info.routes.first.displayColor, 0xFFCB6418);
    expect(info.routes.last.mode, TransitMode.subway);
  });

  test('a payload with no usable place is null', () {
    expect(MotisStopDto.stopInfoFromResponse(null), isNull);
    expect(MotisStopDto.stopInfoFromResponse(<String, Object?>{}), isNull);
    expect(
      MotisStopDto.stopInfoFromResponse(<String, Object?>{
        'place': <String, Object?>{'lat': 52.5, 'lon': 13.4},
      }),
      isNull,
    );
  });

  test('a radius anchor without a stop id keeps its routes', () {
    final TransitStopInfo? info = MotisStopDto.stopInfoFromResponse(
      <String, Object?>{
        'place': <String, Object?>{'name': 'center', 'lat': 52.5, 'lon': 13.4},
        'routes': <Object?>[
          <String, Object?>{'mode': 'TRAM', 'routeShortName': 'M4'},
        ],
      },
    );
    expect(info, isNotNull);
    expect(info!.stopId, isEmpty);
    expect(info.name, 'center');
    expect(info.routes.single.lineLabel, 'M4');
  });

  test('hostile fields are dropped, not thrown on', () {
    final TransitStopInfo? info = MotisStopDto.stopInfoFromResponse(
      <String, Object?>{
        'place': <String, Object?>{'name': 42, 'stopId': 'de:1', 'lat': 'x'},
        'routes': <Object?>[
          'not a map',
          <String, Object?>{
            'mode': <String>['bad'],
            'routeShortName': 7,
          },
          <String, Object?>{'routeShortName': '  '},
          <String, Object?>{'mode': 'BUS', 'routeShortName': 'Bus 100'},
        ],
      },
    );

    expect(info, isNotNull);
    // The name and position are missing/invalid, so the id is the name.
    expect(info!.name, 'de:1');
    expect(info.position, isNull);
    expect(info.routes, hasLength(1));
    expect(info.routes.single.lineLabel, 'Bus 100');
  });
}
