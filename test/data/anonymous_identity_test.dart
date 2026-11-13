import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_anonymous_identity.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/nostr/ndk_anonymous_identity.dart';
import 'package:openmaps/domain/entities/nostr_identity.dart';

/// The persistent anonymous identity: generated once on demand, stored in the
/// local database, and reused verbatim on every later call and run.
void main() {
  bool isHex(String value) => RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

  test('generates a signing key pair and persists it', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    final NdkAnonymousIdentity identity = NdkAnonymousIdentity(database: db);

    final NostrIdentity? first = await identity.current();
    expect(first, isNotNull);
    expect(isHex(first!.pubkey), isTrue);
    expect(isHex(first.privateKey), isTrue);
    expect(first.canSign, isTrue);

    // Stored as a value under the dedicated key (no schema change).
    expect(await db.readSetting(NdkAnonymousIdentity.storageKey), isNotNull);

    // The same call returns the very same identity.
    expect(await identity.current(), first);
  });

  test('a second instance over the same store reuses the stored key', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    final NostrIdentity? first = await NdkAnonymousIdentity(database: db)
        .current();
    final NostrIdentity? second = await NdkAnonymousIdentity(database: db)
        .current();

    expect(first, isNotNull);
    expect(second, first);
  });

  test('concurrent first calls mint exactly one identity', () async {
    final InMemoryAppDatabase db = InMemoryAppDatabase();
    final NdkAnonymousIdentity identity = NdkAnonymousIdentity(database: db);

    final List<NostrIdentity?> results = await Future.wait(
      <Future<NostrIdentity?>>[identity.current(), identity.current()],
    );
    expect(results[0], isNotNull);
    expect(results[1], results[0]);
  });

  test('a missing or corrupt stored value is regenerated, not fatal', () async {
    final List<String> storedValues = <String>[
      'not json at all',
      '{"pubkey":"too-short","privateKey":"nope"}',
      '{"pubkey":"${'a' * 64}"}',
      '{"privateKey":"${'b' * 64}"}',
    ];
    for (final String stored in storedValues) {
      final InMemoryAppDatabase db = InMemoryAppDatabase();
      await db.writeSetting(NdkAnonymousIdentity.storageKey, stored);

      final NostrIdentity? identity = await NdkAnonymousIdentity(database: db)
          .current();
      expect(identity, isNotNull, reason: 'stored: $stored');
      expect(isHex(identity!.pubkey), isTrue);
      expect(isHex(identity.privateKey), isTrue);
    }
  });

  test('fake generates once and stays stable', () async {
    final FakeAnonymousIdentity fake = FakeAnonymousIdentity();
    final NostrIdentity? first = await fake.current();
    final NostrIdentity? second = await fake.current();

    expect(first, isNotNull);
    expect(isHex(first!.pubkey), isTrue);
    expect(second, first);
    expect(fake.generated, 1);
  });

  test('fake can model a device that cannot provide an identity', () async {
    final FakeAnonymousIdentity fake = FakeAnonymousIdentity(
      generateKeyOnDemand: false,
    );
    expect(await fake.current(), isNull);
  });
}
