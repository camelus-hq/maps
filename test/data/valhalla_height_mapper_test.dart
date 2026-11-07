import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/valhalla/valhalla_height_mapper.dart';
import 'package:openmaps/domain/entities/elevation.dart';

void main() {
  test('maps range_height pairs into a profile', () {
    final ElevationProfile profile = ValhallaHeightMapper.fromResponse(
      <String, Object?>{
        'range_height': <Object?>[
          <Object?>[0, 40.0],
          <Object?>[50, 48.5],
          <Object?>[100, 44],
        ],
      },
    );
    expect(profile.isUsable, isTrue);
    expect(profile.points, hasLength(3));
    expect(profile.points[1].distanceMeters, 50);
    expect(profile.points[1].elevationMeters, 48.5);
    expect(profile.ascent, closeTo(8.5, 1e-6));
  });

  test('all-null heights (no elevation dataset) degrade to empty', () {
    final ElevationProfile profile = ValhallaHeightMapper.fromResponse(
      <String, Object?>{
        'range_height': <Object?>[
          <Object?>[0, null],
          <Object?>[50, null],
        ],
      },
    );
    expect(profile.isEmpty, isTrue);
  });

  test('hostile payloads never throw', () {
    expect(ValhallaHeightMapper.fromResponse(null).isEmpty, isTrue);
    expect(ValhallaHeightMapper.fromResponse('nope').isEmpty, isTrue);
    expect(
      ValhallaHeightMapper.fromResponse(<String, Object?>{
        'range_height': 'not a list',
      }).isEmpty,
      isTrue,
    );
    // Mixed junk: short entries, non-numeric values, out-of-order distances.
    final ElevationProfile profile = ValhallaHeightMapper.fromResponse(
      <String, Object?>{
        'range_height': <Object?>[
          <Object?>[0, 10.0],
          <Object?>[5], // too short
          <Object?>['x', 'y'], // not numeric
          <Object?>[100, 20.0],
          <Object?>[80, 99.0], // out of order → dropped
          <Object?>[200, double.nan], // non-finite → dropped
        ],
      },
    );
    expect(profile.points, hasLength(2));
    expect(profile.points.last.elevationMeters, 20.0);
  });
}
