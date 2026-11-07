import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/cycling_options.dart';

void main() {
  test('defaults mirror Valhalla (hybrid, neutral weights, 18 km/h)', () {
    const CyclingOptions options = CyclingOptions.defaults;
    expect(options.bicycleType, BicycleType.hybrid);
    expect(options.useHills, 0.25);
    expect(options.avoidBadSurfaces, 0.25);
    expect(options.useRoads, 0.25);
    // No explicit speed: the hybrid default (18 km/h) applies.
    expect(options.cyclingSpeed, isNull);
    expect(options.effectiveCyclingSpeed, 18);
    expect(options.avoidEdges, isFalse);
  });

  test('an untouched option set sends no overrides', () {
    expect(CyclingOptions.defaults.changedOptions(), isEmpty);
  });

  test('only the changed options are sent', () {
    const CyclingOptions options = CyclingOptions(
      bicycleType: BicycleType.mountain,
      useHills: 0.8,
      avoidEdges: true,
    );
    expect(options.changedOptions(), <String, Object?>{
      'bicycle_type': 'mountain',
      'use_hills': 0.8,
      'avoid_edges': true,
    });
  });

  test('the type default speed is omitted; an override is sent', () {
    const CyclingOptions road = CyclingOptions(bicycleType: BicycleType.road);
    expect(road.changedOptions(), <String, Object?>{'bicycle_type': 'road'});

    // An explicit speed equal to the type default is a no-op, so it is omitted.
    expect(road.copyWith(cyclingSpeed: 25).changedOptions(), <String, Object?>{
      'bicycle_type': 'road',
    });
    // A real override is sent.
    expect(
      road.copyWith(cyclingSpeed: 31).changedOptions()['cycling_speed'],
      31,
    );
  });

  test('hostile weights/speed are clamped, never nonsensical', () {
    const CyclingOptions options = CyclingOptions(
      useHills: 5,
      useRoads: -2,
      cyclingSpeed: 999,
    );
    final Map<String, Object?> changed = options.changedOptions();
    expect(changed['use_hills'], 1);
    expect(changed['use_roads'], 0);
    expect(changed['cycling_speed'], 60);
  });

  test('BicycleType.parse is case-insensitive and falls back safely', () {
    expect(BicycleType.parse('Road'), BicycleType.road);
    expect(BicycleType.parse('MOUNTAIN'), BicycleType.mountain);
    expect(BicycleType.parse('mtb'), BicycleType.mountain);
    expect(BicycleType.parse('cargo'), BicycleType.hybrid);
    expect(BicycleType.parse(null), BicycleType.hybrid);
    expect(BicycleType.parse(7), BicycleType.hybrid);
  });

  test('toJson reports the effective values', () {
    const CyclingOptions options = CyclingOptions(
      bicycleType: BicycleType.road,
      cyclingSpeed: 22,
    );
    expect(options.toJson(), <String, Object?>{
      'bicycle_type': 'road',
      'use_hills': 0.25,
      'avoid_bad_surfaces': 0.25,
      'cycling_speed': 22.0,
      'use_roads': 0.25,
      'avoid_edges': false,
    });
  });
}
