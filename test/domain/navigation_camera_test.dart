import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/navigation_camera.dart';
import 'package:openmaps/domain/entities/route.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';

const Maneuver _turn = Maneuver(
  instruction: 'Turn right',
  type: ManeuverType.turnRight,
  distanceMeters: 100,
);

double _zoom({
  TravelMode mode = TravelMode.drive,
  double? speed,
  Maneuver? maneuver,
  double distance = 1000,
}) => NavigationCamera.zoom(
  mode: mode,
  speedMetersPerSecond: speed,
  nextManeuver: maneuver,
  distanceToNextManeuver: distance,
);

void main() {
  test('a stopped or speed-less session holds the close-in zoom', () {
    expect(_zoom(speed: 0), NavigationCamera.baseZoom);
    expect(_zoom(speed: null), NavigationCamera.baseZoom);
  });

  test('drive zooms out with speed, floored at the mode minimum', () {
    final double slow = _zoom(speed: 4);
    final double mid = _zoom(speed: 16);
    final double fast = _zoom(speed: 28);
    final double over = _zoom(speed: 60);

    expect(slow, NavigationCamera.baseZoom);
    expect(mid, lessThan(slow));
    expect(fast, lessThan(mid));
    // Past the mode's full speed the zoom does not fall further.
    expect(
      fast,
      closeTo(NavigationCamera.profileFor(TravelMode.drive).minZoom, 1e-9),
    );
    expect(over, fast);
    // Never more zoomed in than the base.
    for (final double speed in <double>[0, 4, 12, 28, 90]) {
      expect(_zoom(speed: speed), lessThanOrEqualTo(NavigationCamera.baseZoom));
    }
  });

  test('cycling and walking zoom out less than driving', () {
    final double drive = _zoom(speed: 25);
    final double cycle = _zoom(speed: 6, mode: TravelMode.cycle);
    final double walk = _zoom(speed: 2, mode: TravelMode.walk);

    expect(cycle, greaterThan(drive));
    expect(walk, greaterThan(cycle));
    expect(walk, greaterThanOrEqualTo(16));
  });

  test('an approaching turn holds the close-in zoom at any speed', () {
    for (final TravelMode mode in <TravelMode>[
      TravelMode.drive,
      TravelMode.cycle,
      TravelMode.walk,
    ]) {
      final double approach = NavigationCamera.profileFor(mode)
          .turnApproachMeters;
      expect(
        _zoom(mode: mode, speed: 50, maneuver: _turn, distance: approach * 0.5),
        NavigationCamera.baseZoom,
        reason: '$mode should hold the turn zoom',
      );
    }
  });

  test('a turn just outside the approach distance still zooms out', () {
    final double approach = NavigationCamera.profileFor(TravelMode.drive)
        .turnApproachMeters;
    expect(
      _zoom(speed: 28, maneuver: _turn, distance: approach + 1),
      lessThan(NavigationCamera.baseZoom),
    );
  });

  test('carrying on, departing and arriving are not turns to hold for', () {
    for (final ManeuverType type in <ManeuverType>[
      ManeuverType.depart,
      ManeuverType.straight,
      ManeuverType.arrive,
      ManeuverType.unknown,
    ]) {
      expect(
        _zoom(
          speed: 28,
          maneuver: Maneuver(type: type, instruction: 'go'),
          distance: 30,
        ),
        lessThan(NavigationCamera.baseZoom),
        reason: '$type should not hold the camera',
      );
    }
    // No maneuver at all (e.g. off-route) is not a turn either.
    expect(_zoom(speed: 28), lessThan(NavigationCamera.baseZoom));
  });

  test('transit keeps one fixed zoom regardless of speed or turn', () {
    expect(
      _zoom(mode: TravelMode.transit, speed: 30, maneuver: _turn, distance: 10),
      NavigationCamera.transitZoom,
    );
    expect(
      _zoom(mode: TravelMode.transit, speed: 0),
      NavigationCamera.transitZoom,
    );
  });

  test('hostile speeds fall back to the stationary zoom', () {
    for (final double speed in <double>[-5, double.nan, double.infinity]) {
      expect(_zoom(speed: speed), NavigationCamera.baseZoom);
    }
  });

  test('a negative distance is never treated as an approaching turn', () {
    expect(
      _zoom(speed: 28, maneuver: _turn, distance: -10),
      lessThan(NavigationCamera.baseZoom),
    );
  });
}
