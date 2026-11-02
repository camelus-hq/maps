import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/dto/valhalla_route_dto.dart';
import 'package:openmaps/domain/entities/route.dart';

void main() {
  test('parses a trip with maneuvers and alternates', () {
    final List<Route> routes = ValhallaRouteDto.routesFromResponse(
      <String, Object?>{
        'trip': <String, Object?>{
          'summary': <String, Object?>{'length': 5.2, 'time': 600},
          'legs': <Object?>[
            <String, Object?>{
              'summary': <String, Object?>{'length': 5.2, 'time': 600},
              'shape': '??o}@_|B',
              'maneuvers': <Object?>[
                <String, Object?>{
                  'instruction': 'Drive north',
                  'type': 1,
                  'length': 1.0,
                },
                <String, Object?>{
                  'instruction': 'Turn right',
                  'type': 10,
                  'length': 4.2,
                },
                <String, Object?>{
                  'instruction': 'Arrive',
                  'type': 4,
                  'length': 0,
                },
              ],
            },
          ],
        },
        'alternates': <Object?>[
          <String, Object?>{
            'trip': <String, Object?>{
              'summary': <String, Object?>{'length': 7.0, 'time': 800},
              'legs': <Object?>[],
            },
          },
        ],
      },
    );

    expect(routes, hasLength(2));
    final Route primary = routes.first;
    expect(primary.distanceMeters, closeTo(5200, 1e-6));
    expect(primary.duration.inSeconds, 600);
    expect(primary.geometry, hasLength(2));
    expect(primary.legs.first.maneuvers, hasLength(3));
    expect(primary.legs.first.maneuvers[1].type, ManeuverType.turnRight);
    expect(primary.legs.first.maneuvers[2].type, ManeuverType.arrive);
    expect(routes[1].distanceMeters, closeTo(7000, 1e-6));
  });

  test('never throws on hostile responses', () {
    for (final Object? raw in <Object?>[
      null,
      42,
      'x',
      <Object?>[],
      <String, Object?>{},
      <String, Object?>{'trip': 'x'},
      <String, Object?>{
        'trip': <String, Object?>{'legs': 'x'},
      },
      <String, Object?>{
        'trip': <String, Object?>{
          'legs': <Object?>['x'],
        },
      },
      <String, Object?>{'alternates': 'x'},
    ]) {
      expect(() => ValhallaRouteDto.routesFromResponse(raw), returnsNormally);
    }
  });
}
