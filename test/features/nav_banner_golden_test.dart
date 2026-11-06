import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/features/navigation/nav_style.dart';
import 'package:openmaps/features/navigation/widgets/nav_widgets.dart';
import 'package:openmaps/state/navigation.dart';

/// Golden for the car instruction banner: the turn glyph, distance, street name
/// and the lane-guidance strip (which the public Valhalla instance does not
/// always return, so it is guarded here).
void main() {
  testWidgets('car instruction banner with lane guidance', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 320);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const NavState nav = NavState(
      status: NavStatus.navigating,
      mode: TravelMode.drive,
      totalMeters: 1700,
      traveledMeters: 1480,
      remaining: Duration(minutes: 6),
      distanceToNextManeuver: 220,
      nextManeuver: Maneuver(
        instruction: 'Turn left onto Bebelplatz',
        type: ManeuverType.turnLeft,
        streetName: 'Bebelplatz',
        lanes: <LaneGuidance>[
          LaneGuidance(
            active: true,
            indications: <LaneIndication>[LaneIndication.left],
          ),
          LaneGuidance(indications: <LaneIndication>[LaneIndication.straight]),
          LaneGuidance(
            indications: <LaneIndication>[
              LaneIndication.straight,
              LaneIndication.right,
            ],
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: const Color(0xFFDDE3E0),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: NavBanner(
                nav: nav,
                style: NavStyle.forMode(TravelMode.drive),
                imperial: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(NavBanner),
      matchesGoldenFile('goldens/nav_banner_drive.png'),
    );
  });
}
