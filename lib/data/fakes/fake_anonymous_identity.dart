import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_identity.dart';
import '../../domain/ports/anonymous_identity.dart';

/// In-memory [AnonymousIdentity] for tests and keyless runs (no platform
/// plugins).
///
/// It still generates a **real** key pair once and returns the same identity
/// afterwards, so the "stable anonymous identity" contract holds without a
/// database. Set [generateKeyOnDemand] to `false` to model a device that cannot
/// provide an identity at all (the `null` path).
class FakeAnonymousIdentity implements AnonymousIdentity {
  FakeAnonymousIdentity({this.identity, this.generateKeyOnDemand = true});

  /// The identity currently held, or `null` before the first [current] call.
  NostrIdentity? identity;

  /// Whether a key pair is generated on the first [current] call.
  final bool generateKeyOnDemand;

  /// How many key pairs were generated (tests).
  int generated = 0;

  @override
  Future<NostrIdentity?> current() async {
    final NostrIdentity? existing = identity;
    if (existing != null) {
      return existing;
    }
    if (!generateKeyOnDemand) {
      return null;
    }
    final (String privateKey, String publicKey) =
        const Bip340EventSignerFactory().generateKeyPair();
    generated++;
    return identity = NostrIdentity(
      pubkey: publicKey.trim().toLowerCase(),
      privateKey: privateKey.trim().toLowerCase(),
    );
  }
}
