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

  test('parses legacy string lane guidance', () {
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
    expect(maneuver.lanes.first.valid, isTrue);
    expect(maneuver.lanes.first.primary, LaneIndication.left);
    expect(maneuver.lanes[1].valid, isFalse);
    expect(maneuver.lanes[1].primary, LaneIndication.straight);
    expect(maneuver.lanes[1].indications, <LaneIndication>[
      LaneIndication.straight,
      LaneIndication.right,
    ]);
  });

  test('parses the direction/valid/active lane bitmasks (docs example)', () {
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
                  // With `turn_lanes: true` the lanes are a flat array on the
                  // maneuver.
                  'lanes': <Object?>[
                    // directions Left(8), active Left(8): the preferred lane
                    // for the left turn.
                    <String, Object?>{'directions': 8, 'active': 8},
                    // directions Left(8) + Through(2), valid Left(8).
                    <String, Object?>{'directions': 10, 'valid': 8},
                  ],
                },
              ],
            },
          ],
        },
      },
    );

    final List<LaneGuidance> lanes =
        routes.first.legs.first.maneuvers.first.lanes;
    expect(lanes, hasLength(2));
    expect(lanes[0].indications, <LaneIndication>[LaneIndication.left]);
    expect(lanes[0].active, isTrue);
    expect(lanes[0].valid, isFalse);
    expect(lanes[0].primary, LaneIndication.left);
    expect(lanes[1].indications, <LaneIndication>[
      LaneIndication.left,
      LaneIndication.straight,
    ]);
    expect(lanes[1].active, isFalse);
    expect(lanes[1].valid, isTrue);
    expect(lanes[1].primary, LaneIndication.left);
  });

  test(
    'parses real Messedamm lane guidance (left|left|through|through|right)',
    () {
      final List<Route> routes = ValhallaRouteDto.routesFromResponse(
        <String, Object?>{
          'trip': <String, Object?>{
            'summary': <String, Object?>{'length': 0.3, 'time': 60},
            'legs': <Object?>[
              <String, Object?>{
                'maneuvers': <Object?>[
                  <String, Object?>{
                    'instruction': 'Turn left to stay on Messedamm.',
                    'type': 15,
                    'length': 0.3,
                    'lanes': <Object?>[
                      <String, Object?>{'directions': 8},
                      <String, Object?>{'directions': 8, 'active': 8},
                      <String, Object?>{'directions': 2},
                      <String, Object?>{'directions': 66},
                      <String, Object?>{'directions': 64},
                    ],
                  },
                ],
              },
            ],
          },
        },
      );

      final List<LaneGuidance> lanes =
          routes.first.legs.first.maneuvers.first.lanes;
      expect(lanes, hasLength(5));
      expect(lanes.map((LaneGuidance lane) => lane.primary), <LaneIndication>[
        LaneIndication.left,
        LaneIndication.left,
        LaneIndication.straight,
        LaneIndication.right, // directions 66 = Right(64) + Through(2)
        LaneIndication.right,
      ]);
      expect(lanes[1].active, isTrue);
      expect(lanes.where((LaneGuidance lane) => lane.active), hasLength(1));
    },
  );

  test('expands every lane direction bit', () {
    expect(LaneIndication.fromBitmask(0), isEmpty);
    expect(LaneIndication.fromBitmask(2), <LaneIndication>[
      LaneIndication.straight,
    ]);
    expect(LaneIndication.fromBitmask(256), <LaneIndication>[
      LaneIndication.reverse,
    ]);
    expect(LaneIndication.fromBitmask(4 | 8 | 16), <LaneIndication>[
      LaneIndication.sharpLeft,
      LaneIndication.left,
      LaneIndication.slightLeft,
    ]);
    expect(LaneIndication.fromBitmask(512 | 1024), <LaneIndication>[
      LaneIndication.mergeLeft,
      LaneIndication.mergeRight,
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

  test('maps maneuver codes to the matching turn direction', () {
    const Map<int, ManeuverType> expected = <int, ManeuverType>{
      1: ManeuverType.depart,
      2: ManeuverType.depart,
      3: ManeuverType.depart,
      4: ManeuverType.arrive,
      5: ManeuverType.arrive,
      6: ManeuverType.arrive,
      7: ManeuverType.straight,
      8: ManeuverType.straight,
      9: ManeuverType.slightRight,
      10: ManeuverType.turnRight,
      11: ManeuverType.sharpRight,
      12: ManeuverType.uTurnRight,
      13: ManeuverType.uTurnLeft,
      14: ManeuverType.sharpLeft,
      15: ManeuverType.turnLeft,
      16: ManeuverType.slightLeft,
      17: ManeuverType.straight,
      18: ManeuverType.rampRight,
      19: ManeuverType.rampLeft,
      20: ManeuverType.exitRight,
      21: ManeuverType.exitLeft,
      22: ManeuverType.straight,
      23: ManeuverType.keepRight,
      24: ManeuverType.keepLeft,
      25: ManeuverType.merge,
      26: ManeuverType.roundabout,
      27: ManeuverType.roundaboutExit,
      37: ManeuverType.mergeRight,
      38: ManeuverType.mergeLeft,
    };
    expected.forEach((int code, ManeuverType type) {
      expect(
        ValhallaRouteDto.maneuverTypeFrom(code),
        type,
        reason: 'Valhalla code $code',
      );
    });
    // Unknown/bad values degrade instead of throwing.
    expect(ValhallaRouteDto.maneuverTypeFrom('x'), ManeuverType.unknown);
    expect(ValhallaRouteDto.maneuverTypeFrom(null), ManeuverType.unknown);
    expect(ValhallaRouteDto.maneuverTypeFrom(999), ManeuverType.unknown);
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
