import 'dart:convert';

import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_identity.dart';
import '../../domain/ports/anonymous_identity.dart';
import '../../domain/ports/app_database.dart';

/// [AnonymousIdentity] backed by the local [AppDatabase] and NDK's key
/// generation.
///
/// The key pair is stored as a JSON object under [storageKey], so it survives
/// restarts on every backend (ObjectBox on native, drift on the web) without a
/// schema change — the settings store is a generic key/value table. The
/// identity is generated **once, on demand**: later calls in this run and every
/// later run return the same key pair.
///
/// **Never crash:** a missing, corrupt or unreadable value is regenerated, and
/// a write failure is swallowed (the identity is still usable for this run, it
/// just will not survive a restart).
class NdkAnonymousIdentity implements AnonymousIdentity {
  NdkAnonymousIdentity({required this.database});

  /// The key the identity is stored under. Like the `settings.*`/`places.*`
  /// keys it needs no migration: the settings store is schemaless.
  static const String storageKey = 'identity.anonymous';

  static final RegExp _hex = RegExp(r'^[0-9a-f]{64}$');

  /// The local store the key pair lives in.
  final AppDatabase database;

  NostrIdentity? _cached;
  Future<NostrIdentity?>? _loading;

  @override
  Future<NostrIdentity?> current() {
    final NostrIdentity? cached = _cached;
    if (cached != null) {
      return Future<NostrIdentity?>.value(cached);
    }
    // Collapse concurrent first calls onto one generation, so two callers never
    // race to mint (and persist) two different identities.
    return _loading ??= _loadOrCreate();
  }

  Future<NostrIdentity?> _loadOrCreate() async {
    final NostrIdentity? stored = await _read();
    if (stored != null) {
      _complete(stored);
      return stored;
    }
    final NostrIdentity generated = _generate();
    try {
      await database.writeSetting(
        storageKey,
        jsonEncode(<String, String>{
          'pubkey': generated.pubkey,
          'privateKey': generated.privateKey,
        }),
      );
    } catch (_) {
      // A read-only or closed store must not stop the identity being used.
    }
    _complete(generated);
    return generated;
  }

  void _complete(NostrIdentity identity) {
    _cached = identity;
    _loading = null;
  }

  Future<NostrIdentity?> _read() async {
    final String? raw;
    try {
      raw = await database.readSetting(storageKey);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final Object? pubkey = decoded['pubkey'];
    final Object? privateKey = decoded['privateKey'];
    if (pubkey is! String || privateKey is! String) {
      return null;
    }
    final String pub = pubkey.trim().toLowerCase();
    final String priv = privateKey.trim().toLowerCase();
    if (!_hex.hasMatch(pub) || !_hex.hasMatch(priv)) {
      return null;
    }
    return NostrIdentity(pubkey: pub, privateKey: priv);
  }

  NostrIdentity _generate() {
    final (String privateKey, String publicKey) =
        const Bip340EventSignerFactory().generateKeyPair();
    return NostrIdentity(
      pubkey: publicKey.trim().toLowerCase(),
      privateKey: privateKey.trim().toLowerCase(),
    );
  }
}
