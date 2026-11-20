import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ndk/ndk.dart' as ndk;
import 'package:serverpod/serverpod.dart';

import 'push_config.dart';
import 'push_dispatcher.dart';
import 'push_filters.dart';
import 'push_repository.dart';
import 'relay_pool.dart';

/// The long-lived server-side forwarder: one relay pool, dynamic `#p`
/// subscriptions, one dedup cache, dispatching events through [PushDispatcher].
///
/// Started once from `server.dart` after the Serverpod instance is up. The
/// endpoint only writes registrations; this service reads them and recomputes
/// the relay subscriptions, so a newly registered device is reachable at once
/// and the server never receives gift wraps for people who did not ask.
class PushService {
  PushService({required this.repository, required this.dispatcher});

  final PushRepository repository;
  final PushDispatcher dispatcher;

  PushRelayPool? _pool;
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  Timer? _cacheTimer;
  bool _started = false;

  /// The filters currently subscribed, keyed by subscription id. The encoded
  /// value is kept so a changed chunk is detected and resubscribed.
  Map<String, Map<String, Object>> _activeFilters =
      <String, Map<String, Object>>{};

  /// Event ids already forwarded, with when they were seen.
  final Map<String, DateTime> _sentCache = <String, DateTime>{};

  /// How many events have been handed to the dispatcher (diagnostics/tests).
  int _forwardedCount = 0;
  int get forwardedCount => _forwardedCount;

  bool get isStarted => _started;
  List<PushRelay> get relays => _pool?.relays ?? const <PushRelay>[];

  /// Connects to every bootstrap/registered relay and starts forwarding. Safe to
  /// call more than once.
  Future<void> start({Serverpod? pod}) async {
    if (_started) {
      return;
    }
    _started = true;
    final Serverpod serverpod = pod ?? Serverpod.instance;

    final Set<String> relays = <String>{...PushConfig.bootstrapRelays};
    List<String> pubkeys = const <String>[];
    try {
      await serverpod.withSession((Session session) async {
        relays.addAll(await repository.allRelays(session));
        pubkeys = await repository.allPubkeys(session);
      });
    } catch (error) {
      // A database problem must not stop the forwarder from coming up;
      // registrations are re-read on the next refresh.
      stderr.writeln('[push] Could not load registrations: $error');
    }

    final PushRelayPool pool = PushRelayPool(
      relays,
      options: const PushRelayOptions(),
    );
    _pool = pool;
    // Copy into a mutable map: refreshSubscriptions mutates this in place, and
    // buildPushFilters may (defensively) return an unmodifiable map.
    _activeFilters = <String, Map<String, Object>>{
      ...buildPushFilters(pubkeys),
    };

    _subscriptions.add(
      pool.onOpen.listen((PushRelay relay) {
        for (final MapEntry<String, Map<String, Object>> entry
            in _activeFilters.entries) {
          relay.subscribe(entry.key, entry.value);
        }
      }),
    );
    _subscriptions.add(
      pool.onEvent.listen((ndk.Nip01Event event) => unawaited(_onEvent(event))),
    );
    _subscriptions.add(
      pool.onError.listen((PushRelayError error) {
        stderr.writeln('[push] Relay ${error.relay.url} error: ${error.error}');
      }),
    );

    _cacheTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _cleanCache(),
    );
    stderr.writeln(
      '[push] Forwarder watching ${relays.length} relays, '
      '${_activeFilters.length} filter(s)',
    );
  }

  /// Adds any [relays] the pool does not watch yet.
  void ensureRelays(Iterable<String> relays) {
    final PushRelayPool? pool = _pool;
    if (pool == null) {
      return;
    }
    for (final String relay in relays) {
      if (pool.add(relay)) {
        stderr.writeln('[push] Forwarder now watching $relay');
      }
    }
  }

  /// Recomputes the `#p` filters from the stored registrations and applies the
  /// difference to the live subscriptions. Called after every registration
  /// change; a no-op before [start].
  Future<void> refreshSubscriptions({Session? session, Serverpod? pod}) async {
    final PushRelayPool? pool = _pool;
    if (pool == null) {
      return;
    }
    final List<String> pubkeys;
    if (session != null) {
      pubkeys = await repository.allPubkeys(session);
    } else {
      pubkeys = await (pod ?? Serverpod.instance).withSession(
        (Session s) => repository.allPubkeys(s),
      );
    }

    final Map<String, Map<String, Object>> next = buildPushFilters(pubkeys);
    final Map<String, String> currentEncoded = <String, String>{
      for (final MapEntry<String, Map<String, Object>> entry
          in _activeFilters.entries)
        entry.key: jsonEncode(entry.value),
    };

    // Close subscriptions that disappeared or changed.
    for (final String id in _activeFilters.keys.toList()) {
      final Map<String, Object>? nextFilter = next[id];
      if (nextFilter == null || jsonEncode(nextFilter) != currentEncoded[id]) {
        pool.unsubscribe(id);
        _activeFilters.remove(id);
      }
    }
    // Open new or changed subscriptions.
    for (final MapEntry<String, Map<String, Object>> entry in next.entries) {
      if (!_activeFilters.containsKey(entry.key)) {
        pool.subscribe(entry.key, entry.value);
        _activeFilters[entry.key] = entry.value;
      }
    }
  }

  Future<void> stop() async {
    _cacheTimer?.cancel();
    _cacheTimer = null;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _pool?.close();
    _pool = null;
    _activeFilters = <String, Map<String, Object>>{};
    _started = false;
  }

  Future<void> _onEvent(ndk.Nip01Event event) async {
    final String id = event.id;
    if (_sentCache.containsKey(id)) {
      return;
    }
    _sentCache[id] = DateTime.now();
    _forwardedCount += 1;
    try {
      await Serverpod.instance.withSession((Session session) async {
        await dispatcher.dispatch(session, event);
      });
    } catch (error, stackTrace) {
      stderr.writeln('[push] Failed to forward event $id: $error\n$stackTrace');
    }
  }

  void _cleanCache() {
    final DateTime now = DateTime.now();
    _sentCache.removeWhere(
      (_, DateTime seen) => now.difference(seen) > PushConfig.sentCacheTtl,
    );
    if (_sentCache.length <= PushConfig.maxSentCacheSize) {
      return;
    }
    final List<MapEntry<String, DateTime>> entries = _sentCache.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final int drop = _sentCache.length - PushConfig.maxSentCacheSize;
    for (int i = 0; i < drop; i++) {
      _sentCache.remove(entries[i].key);
    }
  }
}
