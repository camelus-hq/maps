import 'lat_lon.dart';

/// A friend's live position drawn on the map (avatar ring + name label).
///
/// Kept separate from the search-result [Marker]s because friend pins carry a
/// label and are drawn by their own annotation layer.
class FriendMarker {
  const FriendMarker({
    required this.pubkey,
    required this.position,
    required this.label,
    this.pictureUrl,
    this.live = true,
  });

  /// The friend's public key (also the tap id).
  final String pubkey;

  final LatLon position;

  /// The name shown next to the pin.
  final String label;

  /// The friend's Nostr profile picture, drawn inside the pin when it loads.
  final String? pictureUrl;

  /// Whether the friend is sharing right now (the badge reads "· Live").
  final bool live;
}
