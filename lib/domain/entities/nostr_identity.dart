/// A Nostr key pair, both keys lowercase 64-character hex.
///
/// [privateKey] is empty for a public-only identity (one that can be read from
/// but cannot sign). The app's **persistent anonymous account** is one of
/// these: generated once and stored locally, reused for every anonymous action.
///
/// The private key is deliberately never part of [toString], so it cannot leak
/// into a log line by accident.
class NostrIdentity {
  const NostrIdentity({required this.pubkey, required this.privateKey});

  /// The public key (lowercase hex).
  final String pubkey;

  /// The private key (lowercase hex), or an empty string when unavailable.
  final String privateKey;

  /// Whether this identity can sign events (a private key is present).
  bool get canSign => privateKey.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is NostrIdentity &&
      other.pubkey == pubkey &&
      other.privateKey == privateKey;

  @override
  int get hashCode => Object.hash(pubkey, privateKey);

  @override
  String toString() => 'NostrIdentity($pubkey)';
}
