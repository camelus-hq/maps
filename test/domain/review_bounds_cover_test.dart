import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/utils/geohash.dart';
import 'package:openmaps/domain/entities/review_bounds.dart';
import 'package:openmaps/domain/entities/review_bounds_cover.dart';

/// The cover is what decides whether a camera move sends a new relay query, so
/// its identity must be stable for viewports that land in the same cells.
void main() {
  test('covers a city viewport with a small set of cells', () {
    final ReviewBoundsCover? cover = ReviewBoundsCover.of(
      const ReviewBounds(north: 52.53, south: 52.51, east: 13.42, west: 13.39),
    );
    expect(cover, isNotNull);
    expect(cover!.prefixes, isNotEmpty);
    expect(
      cover.prefixes.length,
      lessThanOrEqualTo(ReviewBoundsCover.maxCells),
    );
    expect(cover.precision, lessThanOrEqualTo(ReviewBoundsCover.maxPrecision));
    // Every cell is a geohash truncated to the chosen precision.
    for (final String cell in cover.prefixes) {
      expect(cell.length, cover.precision);
    }
    // A point inside the rectangle is under one of the cells.
    final String inside = Geohash.encode(52.52, 13.405, precision: 6);
    expect(cover.prefixes.any(inside.startsWith), isTrue);
  });

  test('the key is order-independent and stable for a tiny pan', () {
    final ReviewBoundsCover a = ReviewBoundsCover.of(
      const ReviewBounds(north: 52.53, south: 52.51, east: 13.42, west: 13.39),
    )!;
    final ReviewBoundsCover b = ReviewBoundsCover.of(
      const ReviewBounds(
        north: 52.5301,
        south: 52.5101,
        east: 13.4201,
        west: 13.3901,
      ),
    )!;
    expect(a.key, b.key);
  });

  test('a worldwide viewport has no tag cover', () {
    final ReviewBoundsCover? cover = ReviewBoundsCover.of(
      const ReviewBounds(north: 85, south: -85, east: 179, west: -179),
    );
    expect(cover, isNull);
  });
}
