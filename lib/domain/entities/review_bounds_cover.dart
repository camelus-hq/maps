import '../../core/utils/geohash.dart';
import 'review_bounds.dart';

/// The geohash cells that cover a visible rectangle for a `#g` relay query.
///
/// Both the data adapter (which turns this into the Nostr filter) and the map
/// controller (which decides whether a camera move actually changes that filter)
/// derive the cover from this one function, so "the filter changed" is decided
/// by exactly what would be queried — a pan inside the same cells needs no new
/// relay request.
class ReviewBoundsCover {
  const ReviewBoundsCover({required this.precision, required this.prefixes});

  /// The geohash precision every prefix in [prefixes] is truncated to.
  final int precision;

  /// The covering cells, **sorted**, so the value (and its [key]) is stable
  /// regardless of how [Geohash.cover] happened to enumerate them.
  final List<String> prefixes;

  /// Precision search stops at this many covering cells.
  static const int maxCells = 24;

  /// Highest geohash precision we cover a viewport at (~150 m cells).
  static const int maxPrecision = 7;

  /// A viewport wider than this cannot be covered with tags.
  static const double maxLonSpan = 180;

  /// A viewport taller than this cannot be covered with tags.
  static const double maxLatSpan = 120;

  /// The [key] used when there is no tag cover (a plain kind query).
  static const String kindOnlyKey = 'all';

  /// The cells covering [bounds] at the coarsest precision that stays within
  /// [maxCells], or `null` when the viewport is too wide for a tag query.
  static ReviewBoundsCover? of(ReviewBounds bounds) {
    if (bounds.lonSpan > maxLonSpan || bounds.latSpan > maxLatSpan) {
      return null;
    }
    for (int precision = maxPrecision; precision >= 1; precision--) {
      final List<String> cells = Geohash.cover(
        north: bounds.north,
        south: bounds.south,
        east: bounds.east,
        west: bounds.west,
        precision: precision,
        maxCells: 8,
      );
      if (cells.isEmpty) {
        continue;
      }
      if (cells.length <= maxCells) {
        final List<String> sorted = <String>[...cells]..sort();
        return ReviewBoundsCover(
          precision: precision,
          prefixes: List<String>.unmodifiable(sorted),
        );
      }
    }
    return null;
  }

  /// A stable identity of the relay filter this cover produces: two equal keys
  /// mean the same `#g` filter (prefix order does not matter).
  String get key => 'p$precision:${prefixes.join(',')}';

  @override
  String toString() =>
      'ReviewBoundsCover(p$precision, ${prefixes.length} cells)';
}
