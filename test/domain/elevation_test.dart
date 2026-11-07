import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/elevation.dart';

ElevationProfile _profile(List<double> heights, {double spacing = 50}) {
  return ElevationProfile(<ElevationPoint>[
    for (int i = 0; i < heights.length; i++)
      ElevationPoint(distanceMeters: i * spacing, elevationMeters: heights[i]),
  ]);
}

void main() {
  test('a flat profile has no ascent or descent', () {
    final ElevationProfile profile = _profile(<double>[40, 40, 40, 40]);
    expect(profile.isUsable, isTrue);
    expect(profile.minElevation, 40);
    expect(profile.maxElevation, 40);
    expect(profile.ascent, 0);
    expect(profile.descent, 0);
    expect(profile.gradeAt(75), 0);
  });

  test('sums ascent and descent over a hill', () {
    // 40 → 90 (climb 50) → 40 (descent 50)
    final ElevationProfile profile = _profile(<double>[40, 90, 40]);
    expect(profile.ascent, closeTo(50, 1e-6));
    expect(profile.descent, closeTo(50, 1e-6));
    expect(profile.minElevation, 40);
    expect(profile.maxElevation, 90);
  });

  test('gradeAt interpolates and returns a signed percentage', () {
    // 0 → 100 m over 100 m of run = 100% grade.
    final ElevationProfile profile = ElevationProfile(const <ElevationPoint>[
      ElevationPoint(distanceMeters: 0, elevationMeters: 0),
      ElevationPoint(distanceMeters: 100, elevationMeters: 100),
    ]);
    expect(profile.elevationAt(50), closeTo(50, 1e-6));
    expect(profile.gradeAt(50, windowMeters: 50), closeTo(100, 1e-6));
  });

  test('maxGradeAhead finds the steepest signed grade ahead', () {
    // Flat for 200 m, then a 20% ramp for 100 m.
    final ElevationProfile profile = ElevationProfile(const <ElevationPoint>[
      ElevationPoint(distanceMeters: 0, elevationMeters: 0),
      ElevationPoint(distanceMeters: 200, elevationMeters: 0),
      ElevationPoint(distanceMeters: 300, elevationMeters: 20),
      ElevationPoint(distanceMeters: 600, elevationMeters: 20),
    ]);
    expect(profile.maxGradeAhead(0, aheadMeters: 500), greaterThan(5));
    // Once past the ramp it is flat again.
    expect(profile.maxGradeAhead(450, aheadMeters: 150), closeTo(0, 1e-6));
  });

  test('fewer than two points is empty', () {
    expect(const ElevationProfile(<ElevationPoint>[]).isUsable, isFalse);
    expect(ElevationProfile.empty.isEmpty, isTrue);
  });
}
