/// Whether a NIP-65 relay is used to read (inbox), write (outbox) or both.
///
/// NIP-65 marks each relay `read`, `write` or neither (both). In the common
/// gossip model the application **reads** (receives mentions/DMs) from its
/// **inbox** relays and **writes** (publishes) to its **outbox** relays.
enum RelayMarker {
  /// Receive only — the relay is an inbox.
  inbox,

  /// Publish only — the relay is an outbox.
  outbox,

  /// Both receive and publish.
  both;

  bool get reads => this != RelayMarker.outbox;

  bool get writes => this != RelayMarker.inbox;

  /// A friendly label for the three choices.
  String get label => switch (this) {
    RelayMarker.inbox => 'Inbox',
    RelayMarker.outbox => 'Outbox',
    RelayMarker.both => 'Both',
  };
}

/// A NIP-65 relay with its read/write marker.
class RelayEntry {
  const RelayEntry({required this.url, this.marker = RelayMarker.both});

  final String url;
  final RelayMarker marker;

  RelayEntry copyWith({String? url, RelayMarker? marker}) =>
      RelayEntry(url: url ?? this.url, marker: marker ?? this.marker);

  @override
  bool operator ==(Object other) =>
      other is RelayEntry && other.url == url && other.marker == marker;

  @override
  int get hashCode => Object.hash(url, marker);

  @override
  String toString() => 'RelayEntry($url, ${marker.name})';
}

/// The signed-in user's relay configuration: NIP-65 (kind 10002, read/write
/// relays) and NIP-17 direct-message relays (kind 10050, inbox relays).
///
/// Relays are **public** — both lists are plain Nostr events — so this is not
/// secret material; the UI still explains what each list is for.
class UserRelays {
  const UserRelays({
    this.nip65 = const <RelayEntry>[],
    this.dm = const <String>[],
  });

  /// The NIP-65 relay list, each with its inbox/outbox marker.
  final List<RelayEntry> nip65;

  /// The NIP-17 direct-message relays: where the user receives encrypted DMs.
  final List<String> dm;

  bool get isEmpty => nip65.isEmpty && dm.isEmpty;

  /// Whether both lists have at least one relay, so the account can be reached.
  bool get isComplete => nip65.isNotEmpty && dm.isNotEmpty;

  UserRelays copyWith({List<RelayEntry>? nip65, List<String>? dm}) =>
      UserRelays(nip65: nip65 ?? this.nip65, dm: dm ?? this.dm);

  @override
  bool operator ==(Object other) =>
      other is UserRelays &&
      _listEquals(other.nip65, nip65) &&
      _listEquals(other.dm, dm);

  @override
  int get hashCode => Object.hash(Object.hashAll(nip65), Object.hashAll(dm));

  static bool _listEquals<T>(List<T> a, List<T> b) {
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
