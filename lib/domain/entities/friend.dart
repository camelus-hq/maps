/// A person the user can share their live location with.
///
/// Friends come from the signed-in Nostr identity's contact list; the display
/// name and picture are optional because they live in a separate profile event
/// that may not have been published or fetched yet.
class Friend {
  const Friend({required this.pubkey, this.displayName, this.pictureUrl});

  /// The friend's Nostr public key (lowercase hex, 64 chars).
  final String pubkey;

  /// The profile name, when the friend has published one.
  final String? displayName;

  /// The profile picture URL, when the friend has published one.
  final String? pictureUrl;

  /// A safe label to show: the profile name when present, else a shortened key.
  String get label {
    final String? trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed.length > 40 ? '${trimmed.substring(0, 40)}…' : trimmed;
    }
    return shortPubkey;
  }

  /// A shortened public key (first 8 / last 4 hex characters).
  String get shortPubkey {
    if (pubkey.length <= 14) {
      return pubkey;
    }
    return '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 4)}';
  }

  Friend copyWith({String? displayName, String? pictureUrl}) => Friend(
    pubkey: pubkey,
    displayName: displayName ?? this.displayName,
    pictureUrl: pictureUrl ?? this.pictureUrl,
  );

  @override
  bool operator ==(Object other) => other is Friend && other.pubkey == pubkey;

  @override
  int get hashCode => pubkey.hashCode;

  @override
  String toString() => 'Friend($shortPubkey)';
}
