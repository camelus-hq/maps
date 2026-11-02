import 'lat_lon.dart';

/// A review cluster drawn on the map: one badge per reviewed place, showing the
/// average rating and, when friends have reviewed it, how many.
///
/// Kept separate from the search-result [Marker]s because the badge carries a
/// label ("★ 4.8 · 3 friends") and is drawn by its own annotation layer.
class ReviewMarker {
  const ReviewMarker({
    required this.placeKey,
    required this.position,
    required this.averageRating,
    required this.reviewCount,
    required this.friendCount,
    this.topFriendName,
  });

  /// Scale the badge is drawn at on the map.
  ///
  /// The composer renders its label at 26 px; 0.7 puts it at ~18 px. Shared by
  /// the map layer (which draws it) and the overlap test in the state layer
  /// (which estimates it), so the two can never drift apart.
  static const double onMapScale = 1;

  /// The badge's size in the composer's own pixels, before [onMapScale].
  static const double baseHeight = 52;
  static const double basePadX = 18;
  static const double baseStarAndGap = 32;
  static const double baseCharWidth = 14;

  /// The reviewed place's key (also the tap id, e.g. `openstreetmap:way/1`).
  final String placeKey;

  final LatLon position;

  /// The average normalised rating in `0..1`.
  final double averageRating;

  final int reviewCount;

  /// How many of the reviews were written by the viewer's friends.
  final int friendCount;

  /// The newest friend reviewer's name, when there is one (used for the
  /// accessibility label).
  final String? topFriendName;

  /// Whether at least one friend has reviewed the place (the badge is then
  /// highlighted, matching the reference app's friend reviews).
  bool get hasFriendReview => friendCount > 0;

  /// The average on the 0–5 star scale, one decimal.
  double get stars => averageRating * 5;

  /// The label drawn inside the badge: "4.8 · 3 friends" for a friend-reviewed
  /// place, else "4.8 · 12".
  String get badgeLabel {
    final String rating = stars.toStringAsFixed(1);
    if (hasFriendReview) {
      return '$rating · $friendCount ${friendCount == 1 ? 'friend' : 'friends'}';
    }
    return '$rating · $reviewCount';
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewMarker &&
      other.placeKey == placeKey &&
      other.position == position &&
      other.averageRating == averageRating &&
      other.reviewCount == reviewCount &&
      other.friendCount == friendCount &&
      other.topFriendName == topFriendName;

  @override
  int get hashCode => Object.hash(
    placeKey,
    position,
    averageRating,
    reviewCount,
    friendCount,
    topFriendName,
  );

  @override
  String toString() => 'ReviewMarker($placeKey, $badgeLabel)';
}
