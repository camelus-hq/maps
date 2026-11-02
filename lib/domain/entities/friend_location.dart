import 'lat_lon.dart';

/// A friend's live location, decrypted from a gift-wrapped share event.
///
/// A "stop" payload arrives as an ended entry (see [ended]) so the state layer
/// can drop the friend's pin immediately instead of waiting for the expiry.
class FriendLocation {
  const FriendLocation({
    required this.pubkey,
    required this.updatedAt,
    required this.expiresAt,
    this.position,
    this.ended = false,
    this.accuracyMeters,
    this.heading,
    this.displayName,
    this.pictureUrl,
    this.sessionId,
  });

  /// How long a share stays live without a fresh update before it is dropped.
  ///
  /// A sender that stops abruptly (killed app, lost network) never sends its
  /// final "stop", so a share also ages out; this keeps a stale pin from
  /// lingering on the map forever.
  static const Duration staleAfter = Duration(minutes: 5);

  /// The friend's Nostr public key (lowercase hex).
  final String pubkey;

  /// Their last published position; `null` only for an ended session that never
  /// reported one.
  final LatLon? position;

  /// When that position was sampled (from the share payload).
  final DateTime updatedAt;

  /// When the friend's share session ends on its own.
  final DateTime expiresAt;

  /// Whether the friend ended the share early.
  final bool ended;

  /// Reported horizontal accuracy in metres, when provided.
  final double? accuracyMeters;

  /// Direction of travel in degrees clockwise from north, when provided.
  final double? heading;

  /// The name the friend sent with their share (may be absent).
  final String? displayName;

  /// The friend's profile picture URL, when known.
  final String? pictureUrl;

  /// Identifies the share session (a new session replaces an older one).
  final String? sessionId;

  /// A safe label: the sent name, else a shortened public key.
  String get label {
    final String? trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed.length > 40 ? '${trimmed.substring(0, 40)}…' : trimmed;
    }
    if (pubkey.length <= 14) {
      return pubkey;
    }
    return '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 4)}';
  }

  /// Whether this location is still live at [now] (has a position, not ended,
  /// not expired and not stale).
  bool isLiveAt(DateTime now) {
    if (ended || position == null) {
      return false;
    }
    if (!now.isBefore(expiresAt)) {
      return false;
    }
    final Duration age = now.difference(updatedAt);
    // Tolerate a small sender clock skew but never treat a future timestamp as
    // fresher than "now".
    return age <= staleAfter;
  }

  /// Minutes left in the share at [now], floored at zero.
  int remainingMinutesAt(DateTime now) {
    final Duration left = expiresAt.difference(now);
    return left.isNegative ? 0 : left.inMinutes;
  }

  FriendLocation copyWithMeta({String? displayName, String? pictureUrl}) =>
      FriendLocation(
        pubkey: pubkey,
        position: position,
        updatedAt: updatedAt,
        expiresAt: expiresAt,
        ended: ended,
        accuracyMeters: accuracyMeters,
        heading: heading,
        displayName: displayName ?? this.displayName,
        pictureUrl: pictureUrl ?? this.pictureUrl,
        sessionId: sessionId,
      );

  /// Equality covers the fields the UI renders, so resolving a sender's profile
  /// (name + picture) after the fact counts as a change and repaints the pin.
  @override
  bool operator ==(Object other) =>
      other is FriendLocation &&
      other.pubkey == pubkey &&
      other.ended == ended &&
      other.position == position &&
      other.updatedAt == updatedAt &&
      other.expiresAt == expiresAt &&
      other.displayName == displayName &&
      other.pictureUrl == pictureUrl;

  @override
  int get hashCode => Object.hash(
    pubkey,
    ended,
    position,
    updatedAt,
    expiresAt,
    displayName,
    pictureUrl,
  );

  @override
  String toString() => 'FriendLocation($pubkey, ended: $ended)';
}
