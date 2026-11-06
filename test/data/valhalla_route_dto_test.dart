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

  test('parses street names and lane guidance', () {
    final List<Route> routes = ValhallaRouteDto.routesFromResponse(
      <String, Object?>{
        'trip': <String, Object?>{
          'summary': <String, Object?>{'length': 1.0, 'time': 120},
          'legs': <Object?>[
            <String, Object?>{
              'maneuvers': <Object?>[
                <String, Object?>{
                  'instruction': 'Turn left onto Bebelplatz',
                  'type': 15,
                  'length': 1.0,
                  'street_names': <Object?>['Bebelplatz', 'Unter den Linden'],
                  'intersections': <Object?>[
                    <String, Object?>{
                      'lanes': <Object?>[
                        <String, Object?>{
                          'valid': true,
                          'indications': <Object?>['left'],
                        },
                        <String, Object?>{
                          'valid': false,
                          'indications': <Object?>['straight', 'right'],
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    );

    final Maneuver maneuver = routes.first.legs.first.maneuvers.first;
    expect(maneuver.streetName, 'Bebelplatz');
    expect(maneuver.lanes, hasLength(2));
    expect(maneuver.lanes.first.active, isTrue);
    expect(maneuver.lanes.first.primary, LaneIndication.left);
    expect(maneuver.lanes[1].active, isFalse);
    expect(maneuver.lanes[1].primary, LaneIndication.straight);
    expect(maneuver.lanes[1].indications, <LaneIndication>[
      LaneIndication.straight,
      LaneIndication.right,
    ]);
  });

  test('hostile lane/street data is bounded and never throws', () {
    final List<Route> routes = ValhallaRouteDto.routesFromResponse(
      <String, Object?>{
        'trip': <String, Object?>{
          'summary': <String, Object?>{'length': 1.0, 'time': 120},
          'legs': <Object?>[
            <String, Object?>{
              'maneuvers': <Object?>[
                <String, Object?>{
                  'instruction': 'x',
                  'street_names': 'not-a-list',
                  'intersections': <Object?>[
                    'x',
                    <String, Object?>{'lanes': 'x'},
                    <String, Object?>{
                      'lanes': <Object?>[
                        'x',
                        <String, Object?>{
                          'indications': List<Object?>.generate(
                            50,
                            (int i) => i.isEven ? 'left' : 42,
                          ),
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    );

    final Maneuver maneuver = routes.first.legs.first.maneuvers.first;
    expect(maneuver.streetName, isNull);
    // The string entry is dropped; the hostile indication list is bounded.
    expect(maneuver.lanes, hasLength(1));
    expect(maneuver.lanes[0].indications.length, lessThanOrEqualTo(4));
    expect(maneuver.lanes[0].primary, LaneIndication.left);
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
