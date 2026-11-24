/// The signed-in user's own Nostr profile fields (NIP-01 kind 0 metadata).
///
/// These fields are **public**: a profile is a plain, unencrypted Nostr event,
/// so any relay or client can read the name, the bio and the picture URL, and
/// copy them. The edit UI says so before the user publishes.
class UserProfile {
  const UserProfile({this.name = '', this.about = '', this.pictureUrl});

  /// The display name shown to friends.
  final String name;

  /// A short public bio.
  final String about;

  /// The profile picture URL (a Blossom or any other https URL), when set.
  final String? pictureUrl;

  /// Bounds applied to the text fields; the relay stores whatever is published,
  /// so the inputs are capped before they reach the network.
  static const int maxNameLength = 80;
  static const int maxAboutLength = 500;

  /// A trimmed copy of [name], capped at [maxNameLength].
  String get safeName => _clean(name, maxNameLength);

  /// A trimmed copy of [about], capped at [maxAboutLength].
  String get safeAbout => _clean(about, maxAboutLength);

  bool get isEmpty =>
      name.trim().isEmpty &&
      about.trim().isEmpty &&
      (pictureUrl ?? '').trim().isEmpty;

  UserProfile copyWith({
    String? name,
    String? about,
    String? pictureUrl,
    bool clearPicture = false,
  }) => UserProfile(
    name: name ?? this.name,
    about: about ?? this.about,
    pictureUrl: clearPicture ? null : (pictureUrl ?? this.pictureUrl),
  );

  static String _clean(String value, int max) {
    final String trimmed = value.trim();
    return trimmed.length <= max ? trimmed : trimmed.substring(0, max);
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.name == name &&
      other.about == about &&
      other.pictureUrl == pictureUrl;

  @override
  int get hashCode => Object.hash(name, about, pictureUrl);

  @override
  String toString() => 'UserProfile(name: $name)';
}
