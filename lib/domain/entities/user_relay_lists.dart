/// The signed-in user's relay configuration: NIP-65 (kind 10002, read/write
/// relays) and NIP-17 direct-message relays (kind 10050, inbox relays).
///
/// Relays are **public** — both lists are plain Nostr events — so this is not
/// secret material; the UI still explains what each list is for.
class UserRelays {
  const UserRelays({this.nip65 = const <String>[], this.dm = const <String>[]});

  /// The NIP-65 relay list: where the user publishes and reads notes from.
  final List<String> nip65;

  /// The NIP-17 direct-message relays: where the user receives encrypted DMs.
  final List<String> dm;

  bool get isEmpty => nip65.isEmpty && dm.isEmpty;

  /// Whether both lists have at least one relay, so the account can be reached.
  bool get isComplete => nip65.isNotEmpty && dm.isNotEmpty;

  UserRelays copyWith({List<String>? nip65, List<String>? dm}) =>
      UserRelays(nip65: nip65 ?? this.nip65, dm: dm ?? this.dm);

  @override
  bool operator ==(Object other) =>
      other is UserRelays &&
      _listEquals(other.nip65, nip65) &&
      _listEquals(other.dm, dm);

  @override
  int get hashCode => Object.hash(Object.hashAll(nip65), Object.hashAll(dm));

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'UserRelays(${nip65.length} nip65, ${dm.length} dm)';
}
