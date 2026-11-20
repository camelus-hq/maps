import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'push_registration.dart';

/// Database access for push subscriptions.
///
/// Kept separate from the endpoint and the forwarder so both can share it and
/// it can be exercised against the real database in tests.
class PushRepository {
  const PushRepository();

  /// Inserts or updates the rows for one verified [registration].
  ///
  /// The unique index is `(pubKey, relay, token)`, so re-registering the same
  /// device on the same relay refreshes its `kinds`/`transport` instead of
  /// piling up duplicates.
  Future<void> save(Session session, PushRegistration registration) async {
    for (final String relay in registration.relays) {
      try {
        final List<PushSubscription> existing = await PushSubscription.db.find(
          session,
          where: (t) =>
              t.pubKey.equals(registration.pubKey) &
              t.relay.equals(relay) &
              t.token.equals(registration.token),
        );
        if (existing.isEmpty) {
          await PushSubscription.db.insertRow(
            session,
            PushSubscription(
              pubKey: registration.pubKey,
              relay: relay,
              token: registration.token,
              transport: registration.transport,
              kinds: registration.kinds,
            ),
          );
        } else {
          await PushSubscription.db.updateRow(
            session,
            existing.first.copyWith(
              transport: registration.transport,
              kinds: registration.kinds,
            ),
          );
        }
      } catch (error) {
        session.log(
          'Failed to store push subscription for '
          '${registration.pubKey}@$relay: $error',
          level: LogLevel.error,
        );
      }
    }
  }

  /// The union of every outer kind any of [pubKey]'s subscriptions asked for.
  ///
  /// An empty result means the identity is not registered at all.
  Future<List<int>> kindsFor(Session session, String pubKey) async {
    final List<PushSubscription> rows = await PushSubscription.db.find(
      session,
      where: (t) => t.pubKey.equals(pubKey),
    );
    final Set<int> kinds = <int>{};
    for (final PushSubscription row in rows) {
      kinds.addAll(row.kinds ?? const <int>[]);
    }
    return kinds.toList(growable: false);
  }

  /// Every `(token, transport)` destination registered for [pubKey].
  Future<List<PushSubscription>> subscriptionsFor(
    Session session,
    String pubKey,
  ) => PushSubscription.db.find(session, where: (t) => t.pubKey.equals(pubKey));

  /// Every relay any identity has registered on (plus, at the call site, the
  /// bootstrap relays).
  Future<List<String>> allRelays(Session session) async {
    final List<PushSubscription> rows = await PushSubscription.db.find(session);
    return <String>{
      for (final PushSubscription row in rows) row.relay,
    }.toList(growable: false);
  }

  /// Every public key with at least one registration, for the relay `#p`
  /// filters.
  Future<List<String>> allPubkeys(Session session) async {
    final List<PushSubscription> rows = await PushSubscription.db.find(session);
    return <String>{
      for (final PushSubscription row in rows) row.pubKey,
    }.toList(growable: false);
  }

  /// Whether [relay] is already used by at least one subscription.
  Future<bool> hasRelay(Session session, String relay) async {
    final int count = await PushSubscription.db.count(
      session,
      where: (t) => t.relay.equals(relay),
    );
    return count > 0;
  }

  /// The relay/kind view of an identity's subscriptions (tokens omitted).
  Future<List<PushSubscriptionInfo>> infoFor(
    Session session,
    String pubKey,
  ) async {
    final List<PushSubscription> rows = await PushSubscription.db.find(
      session,
      where: (t) => t.pubKey.equals(pubKey),
    );
    final Map<String, Set<int>> byRelay = <String, Set<int>>{};
    for (final PushSubscription row in rows) {
      byRelay
          .putIfAbsent(row.relay, () => <int>{})
          .addAll(row.kinds ?? const <int>[]);
    }
    return <PushSubscriptionInfo>[
      for (final MapEntry<String, Set<int>> entry in byRelay.entries)
        PushSubscriptionInfo(relay: entry.key, kinds: entry.value.toList()),
    ];
  }

  /// Removes a dead token everywhere (e.g. FCM reported it unregistered).
  Future<void> deleteToken(Session session, String token) async {
    await PushSubscription.db.deleteWhere(
      session,
      where: (t) => t.token.equals(token),
    );
  }

  /// Removes an identity's registration, optionally only for one token.
  Future<void> deleteSubscription(
    Session session,
    String pubKey, {
    String? token,
  }) async {
    if (token == null) {
      await PushSubscription.db.deleteWhere(
        session,
        where: (t) => t.pubKey.equals(pubKey),
      );
    } else {
      await PushSubscription.db.deleteWhere(
        session,
        where: (t) => t.pubKey.equals(pubKey) & t.token.equals(token),
      );
    }
  }
}
