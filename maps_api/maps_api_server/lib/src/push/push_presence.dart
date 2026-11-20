/// Tracks identities that currently have a **live client connection** to this
/// server (the app's foreground streaming method).
///
/// While an identity is connected, the app is receiving gift wraps on its own
/// relay subscription, so the forwarder pauses pushes for it — a push would only
/// duplicate what the app already has. The entry is removed when the connection
/// ends (the app backgrounds, or Serverpod's websocket ping times it out), and
/// forwarding resumes.
///
/// In-memory on purpose: a connection is inherently tied to this process, and
/// the client re-asserts it on the next foreground. A server restart simply
/// starts with nobody connected.
class PushPresence {
  /// Public key → number of open connections. A reference count rather than a
  /// set, so a reconnect that briefly overlaps the old socket does not resume
  /// pushing when the first one closes.
  final Map<String, int> _connections = <String, int>{};

  /// Whether [pubKey] currently has at least one live connection.
  bool isActive(String pubKey) => _connections.containsKey(pubKey);

  /// How many identities are connected (diagnostics/tests).
  int get activeCount => _connections.length;

  /// Records one open connection for [pubKey].
  void add(String pubKey) {
    _connections.update(pubKey, (int count) => count + 1, ifAbsent: () => 1);
  }

  /// Records that one connection for [pubKey] closed.
  void remove(String pubKey) {
    final int? count = _connections[pubKey];
    if (count == null) {
      return;
    }
    if (count <= 1) {
      _connections.remove(pubKey);
    } else {
      _connections[pubKey] = count - 1;
    }
  }

  /// Drops every connection (tests / shutdown).
  void clear() => _connections.clear();
}
