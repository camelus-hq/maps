import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/format.dart';
import '../data/fakes/fake_social_service.dart';
import '../domain/entities/friend.dart';
import '../domain/entities/friend_location.dart';
import '../domain/entities/friend_marker.dart';
import '../domain/entities/lat_lon.dart';
import '../domain/entities/live_share.dart';
import '../domain/entities/location_sample.dart';
import '../domain/ports/social_service.dart';
import '../domain/usecases/load_friends.dart';
import '../domain/usecases/publish_live_share.dart';
import '../domain/usecases/watch_friend_locations.dart';
import 'ports.dart';

/// The ndk_flutter wrapper that drives the login/profile widgets, or `null` in
/// keyless/test builds. Overridden at the composition root so the login screen
/// never touches the NDK directly.
final Provider<NdkFlutter?> ndkFlutterProvider = Provider<NdkFlutter?>(
  (Ref ref) => null,
);

/// The keyless demo service when the app runs on fakes, else `null`.
///
/// Lets the control channel inject a synthetic friend share
/// (`social.simulate.friendLocation`) so the friend UI can be driven and
/// screenshotted without a real second Nostr identity.
final Provider<FakeSocialService?> demoSocialServiceProvider =
    Provider<FakeSocialService?>((Ref ref) {
      final SocialService service = ref.watch(socialServiceProvider);
      return service is FakeSocialService ? service : null;
    });

/// Use-case providers (the seam between state and domain).
final Provider<LoadFriends> loadFriendsProvider = Provider<LoadFriends>(
  (Ref ref) => LoadFriends(ref.watch(socialServiceProvider)),
);

final Provider<WatchFriendLocations> watchFriendLocationsProvider =
    Provider<WatchFriendLocations>(
      (Ref ref) => WatchFriendLocations(ref.watch(socialServiceProvider)),
    );

final Provider<PublishLiveShare> publishLiveShareProvider =
    Provider<PublishLiveShare>(
      (Ref ref) => PublishLiveShare(ref.watch(socialServiceProvider)),
    );

/// The signed-in Nostr public key (null when signed out), kept reactive as
/// accounts are added/removed.
final StreamProvider<String?> nostrPubkeyProvider = StreamProvider<String?>(
  (Ref ref) => ref.watch(socialServiceProvider).identityChanges,
);

/// The signed-in user's friends, loaded from their Nostr contact list.
class FriendsController extends AsyncNotifier<List<Friend>> {
  @override
  Future<List<Friend>> build() async {
    // Re-load whenever the identity changes (login/logout/switch).
    ref.watch(nostrPubkeyProvider);
    if (ref.read(socialServiceProvider).currentUserPubkey == null) {
      return const <Friend>[];
    }
    return ref.read(loadFriendsProvider)();
  }

  /// Re-fetches the contact list and profiles.
  Future<void> refresh() async {
    state = const AsyncValue<List<Friend>>.loading();
    state = await AsyncValue.guard(() => ref.read(loadFriendsProvider)());
  }
}

final AsyncNotifierProvider<FriendsController, List<Friend>> friendsProvider =
    AsyncNotifierProvider<FriendsController, List<Friend>>(
      FriendsController.new,
    );

/// The people the signed-in user follows (NIP-02), for the add-friends UI.
final FutureProvider<List<Friend>> followingsProvider =
    FutureProvider<List<Friend>>((Ref ref) {
      ref.watch(nostrPubkeyProvider);
      if (ref.read(socialServiceProvider).currentUserPubkey == null) {
        return Future<List<Friend>>.value(const <Friend>[]);
      }
      return ref.read(socialServiceProvider).loadFollowings();
    });

/// The signed-in user's own profile (name + picture), for the "My code" QR
/// screen; `null` when signed out.
final FutureProvider<Friend?> myProfileProvider = FutureProvider<Friend?>((
  Ref ref,
) async {
  // Re-resolve whenever the identity changes (login/logout/switch) so the
  // account avatar and settings row follow the signed-in user.
  ref.watch(nostrPubkeyProvider);
  final SocialService service = ref.watch(socialServiceProvider);
  final String? me = service.currentUserPubkey;
  if (me == null) {
    return null;
  }
  return service.resolveProfile(me);
});

/// Friends keyed by public key, for name/avatar lookups in the UI.
final Provider<Map<String, Friend>> friendsByPubkeyProvider =
    Provider<Map<String, Friend>>((Ref ref) {
      final List<Friend> friends =
          ref.watch(friendsProvider).value ?? const <Friend>[];
      return <String, Friend>{
        for (final Friend friend in friends) friend.pubkey: friend,
      };
    });

/// The friends currently sharing their live location with us.
class FriendLocationsController extends Notifier<List<FriendLocation>> {
  final Map<String, FriendLocation> _byPubkey = <String, FriendLocation>{};
  final Set<String> _metaRequested = <String>{};
  StreamSubscription<FriendLocation>? _sub;
  Timer? _prune;

  @override
  List<FriendLocation> build() {
    ref.onDispose(() {
      unawaited(_sub?.cancel());
      _prune?.cancel();
    });
    _sub = ref
        .watch(watchFriendLocationsProvider)()
        .listen(
          _onLocation,
          onError: (Object _) {
            // A relay/subscription error must not take the map down.
          },
        );
    // A prune timer is started lazily by [_syncPruneTimer] only while at least
    // one friend is live, so an idle app (and the test suite) holds no
    // background timer.
    return const <FriendLocation>[];
  }

  void _onLocation(FriendLocation location) {
    if (location.ended) {
      _byPubkey.remove(location.pubkey);
    } else {
      _byPubkey[location.pubkey] = location;
    }
    _syncPruneTimer();
    _emit();
    if (!location.ended) {
      unawaited(_resolveMeta(location.pubkey));
    }
  }

  /// Fetches a sender's profile once per session so their pin shows a name and
  /// avatar even when they are not in the friends list.
  Future<void> _resolveMeta(String pubkey) async {
    if (!_metaRequested.add(pubkey)) {
      return;
    }
    final FriendLocation? current = _byPubkey[pubkey];
    if (current == null ||
        (current.displayName != null && current.pictureUrl != null)) {
      return;
    }
    try {
      final Friend profile = await ref
          .read(socialServiceProvider)
          .resolveProfile(pubkey);
      final FriendLocation? latest = _byPubkey[pubkey];
      if (latest == null) {
        return;
      }
      _byPubkey[pubkey] = latest.copyWithMeta(
        displayName: profile.displayName,
        pictureUrl: profile.pictureUrl,
      );
      _emit();
    } catch (_) {
      // A missing profile just means the pin keeps its key/id.
    }
  }

  /// Expires shares that stop updating even when no new events arrive.
  void _syncPruneTimer() {
    if (_byPubkey.isEmpty) {
      _prune?.cancel();
      _prune = null;
      return;
    }
    _prune ??= Timer.periodic(
      const Duration(seconds: 30),
      (Timer _) => _pruneNow(),
    );
  }

  void _pruneNow() {
    final DateTime now = DateTime.now();
    final int before = _byPubkey.length;
    _byPubkey.removeWhere((String _, FriendLocation location) {
      return !location.isLiveAt(now);
    });
    if (_byPubkey.length != before) {
      _syncPruneTimer();
      _emit();
    }
  }

  void _emit() {
    final DateTime now = DateTime.now();
    final List<FriendLocation> live =
        _byPubkey.values
            .where((FriendLocation location) => location.isLiveAt(now))
            .toList()
          ..sort(
            (FriendLocation a, FriendLocation b) =>
                a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    if (_sameAsState(live)) {
      return;
    }
    state = List<FriendLocation>.unmodifiable(live);
  }

  bool _sameAsState(List<FriendLocation> next) {
    if (next.length != state.length) {
      return false;
    }
    for (int i = 0; i < next.length; i++) {
      if (next[i] != state[i]) {
        return false;
      }
    }
    return true;
  }
}

final NotifierProvider<FriendLocationsController, List<FriendLocation>>
friendLocationsProvider =
    NotifierProvider<FriendLocationsController, List<FriendLocation>>(
      FriendLocationsController.new,
    );

/// Keeps the on-map friend badges in sync with live friend locations.
///
/// The map home watches this so it is instantiated once and stays alive while
/// the app runs (the search route unmounts the map; [MapService.setFriendMarkers]
/// stashes the markers and replays them on re-attach).
class FriendMarkersController extends Notifier<List<FriendMarker>> {
  @override
  List<FriendMarker> build() {
    ref.listen<List<FriendLocation>>(
      friendLocationsProvider,
      (List<FriendLocation>? _, List<FriendLocation> next) => _sync(next),
    );
    Future<void>.microtask(() => _sync(ref.read(friendLocationsProvider)));
    return const <FriendMarker>[];
  }

  void _sync(List<FriendLocation> locations) {
    final Map<String, Friend> friends = ref.read(friendsByPubkeyProvider);
    final List<FriendMarker> markers = <FriendMarker>[];
    for (final FriendLocation location in locations) {
      final LatLon? position = location.position;
      if (position == null) {
        continue;
      }
      final Friend? friend = friends[location.pubkey];
      markers.add(
        FriendMarker(
          pubkey: location.pubkey,
          position: position,
          label: friend?.label ?? location.label,
          pictureUrl: friend?.pictureUrl ?? location.pictureUrl,
        ),
      );
    }
    state = List<FriendMarker>.unmodifiable(markers);
    unawaited(ref.read(mapServiceProvider).setFriendMarkers(markers));
  }
}

final NotifierProvider<FriendMarkersController, List<FriendMarker>>
friendMarkersProvider =
    NotifierProvider<FriendMarkersController, List<FriendMarker>>(
      FriendMarkersController.new,
    );

/// The friend whose location sheet is open over the map.
class SelectedFriendController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? pubkey) {
    state = (pubkey == null || pubkey.isEmpty) ? null : pubkey;
  }

  void clear() => state = null;
}

final NotifierProvider<SelectedFriendController, String?>
selectedFriendProvider = NotifierProvider<SelectedFriendController, String?>(
  SelectedFriendController.new,
);

/// Controls the outgoing live-location share (start/pause/publish/stop).
class LiveShareController extends Notifier<LiveShareState> {
  /// A new update is published at least this often while sharing.
  static const Duration _minInterval = Duration(seconds: 30);

  /// A move of at least this many metres publishes immediately between ticks.
  static const double _minMoveMeters = 25;

  static final Random _random = Random.secure();

  StreamSubscription<LocationSample>? _sub;
  Timer? _expiryTimer;
  LiveShareSession? _session;
  DateTime? _lastPublishedAt;
  LatLon? _lastPublishedPosition;
  LocationSample? _lastSample;

  @override
  LiveShareState build() {
    ref.onDispose(_teardown);
    unawaited(_restore());
    return const LiveShareState();
  }

  /// Re-adopts a persisted session after a restart, if it has not expired.
  Future<void> _restore() async {
    final LiveShareSession? session = await ref
        .read(liveShareStoreProvider)
        .load();
    if (!ref.mounted || session == null) {
      return;
    }
    if (!session.expiresAt.isAfter(DateTime.now())) {
      await ref.read(liveShareStoreProvider).clear();
      return;
    }
    if (ref.read(socialServiceProvider).currentUserPubkey == null) {
      await ref.read(liveShareStoreProvider).clear();
      return;
    }
    _session = session;
    state = LiveShareState(
      status: LiveShareStatus.active,
      recipients: session.recipients,
      startedAt: session.startedAt,
      expiresAt: session.expiresAt,
    );
    await _showNotification(session);
    if (!ref.mounted) {
      return;
    }
    _scheduleExpiry(session);
    _listenToLocation();
  }

  /// Starts sharing with [recipients] for [duration].
  Future<void> start({
    required List<String> recipients,
    Duration duration = defaultLiveShareDuration,
  }) async {
    if (state.isActive || state.isBusy) {
      return;
    }
    if (recipients.isEmpty) {
      state = state.copyWith(
        status: LiveShareStatus.error,
        error: 'Select at least one friend to share with',
      );
      return;
    }
    state = LiveShareState(
      status: LiveShareStatus.starting,
      recipients: List<String>.unmodifiable(recipients),
    );
    // Bounded wait: a permission prompt the user never answers must not leave
    // the card spinning forever.
    final LocationSample? sample;
    try {
      sample = await ref
          .read(locationServiceProvider)
          .lastKnown()
          .timeout(const Duration(seconds: 20), onTimeout: () => null);
    } on Exception {
      _fail('Turn on location access so friends can see where you are.');
      return;
    }
    if (!ref.mounted) {
      return;
    }
    if (sample == null) {
      _fail('Turn on location access so friends can see where you are.');
      return;
    }
    final DateTime now = DateTime.now();
    final LiveShareSession session = LiveShareSession(
      sessionId: newSessionId(),
      recipients: List<String>.unmodifiable(recipients),
      startedAt: now,
      expiresAt: now.add(duration),
    );
    _session = session;
    _lastSample = sample;
    try {
      await ref.read(liveShareStoreProvider).save(session);
      await ref.read(liveShareNotificationsProvider).requestPermission();
      await _send(
        LiveShareBroadcast(
          sessionId: session.sessionId,
          kind: LiveShareBroadcastKind.update,
          position: sample.position,
          sampledAt: now,
          expiresAt: session.expiresAt,
          accuracyMeters: sample.accuracyMeters,
          heading: sample.bearing,
        ),
        session.recipients,
      );
    } on AppException catch (error) {
      _session = null;
      _lastSample = null;
      if (!ref.mounted) {
        return;
      }
      await ref.read(liveShareStoreProvider).clear();
      await ref.read(liveShareNotificationsProvider).dismiss();
      state = LiveShareState(
        status: LiveShareStatus.error,
        recipients: session.recipients,
        error: error.message,
      );
      return;
    }
    _lastPublishedAt = now;
    _lastPublishedPosition = sample.position;
    state = LiveShareState(
      status: LiveShareStatus.active,
      recipients: session.recipients,
      startedAt: session.startedAt,
      expiresAt: session.expiresAt,
      lastPublishedAt: now,
    );
    await _showNotification(session);
    if (!ref.mounted) {
      return;
    }
    _scheduleExpiry(session);
    _listenToLocation();
  }

  /// Puts the controller into a user-readable error state.
  void _fail(String message) {
    state = LiveShareState(
      status: LiveShareStatus.error,
      recipients: state.recipients,
      error: message,
    );
  }

  /// Stops sharing now (publishing a final "stop" so friends drop the pin).
  Future<void> stop() async {
    final LiveShareSession? session = _session;
    final LocationSample? lastSample = _lastSample;
    _teardown();
    _session = null;
    _lastPublishedAt = null;
    _lastPublishedPosition = null;
    _lastSample = null;
    state = const LiveShareState();
    await ref.read(liveShareStoreProvider).clear();
    await ref.read(liveShareNotificationsProvider).dismiss();
    if (session == null || !ref.mounted) {
      return;
    }
    try {
      await _send(
        LiveShareBroadcast(
          sessionId: session.sessionId,
          kind: LiveShareBroadcastKind.stop,
          position: lastSample?.position,
          sampledAt: DateTime.now(),
          expiresAt: DateTime.now(),
        ),
        session.recipients,
      );
    } on AppException {
      // Best-effort: friends still drop the pin at the expiry.
    }
  }

  /// Publishes an extra update right now if a share is active (used by the
  /// control channel so a test/demo can force a fresh pin).
  Future<void> publishNow() async {
    final LiveShareSession? session = _session;
    final LocationSample? sample = _lastSample;
    if (session == null || !state.isActive) {
      return;
    }
    await _sendUpdate(session, sample);
  }

  void _listenToLocation() {
    _sub?.cancel();
    _sub = ref
        .read(locationServiceProvider)
        .positionStream()
        .listen(_onSample, onError: (Object _) {});
  }

  void _onSample(LocationSample sample) {
    if (!state.isActive) {
      return;
    }
    _lastSample = sample;
    final DateTime now = DateTime.now();
    final DateTime? lastAt = _lastPublishedAt;
    final LatLon? lastPosition = _lastPublishedPosition;
    final bool stale = lastAt == null || now.difference(lastAt) >= _minInterval;
    final bool moved =
        lastPosition == null ||
        lastPosition.distanceTo(sample.position) >= _minMoveMeters;
    if (!stale && !moved) {
      return;
    }
    final LiveShareSession? session = _session;
    if (session == null) {
      return;
    }
    unawaited(_sendUpdate(session, sample));
  }

  Future<void> _sendUpdate(
    LiveShareSession session,
    LocationSample? sample,
  ) async {
    final DateTime now = DateTime.now();
    try {
      await _send(
        LiveShareBroadcast(
          sessionId: session.sessionId,
          kind: LiveShareBroadcastKind.update,
          position: sample?.position,
          sampledAt: now,
          expiresAt: session.expiresAt,
          accuracyMeters: sample?.accuracyMeters,
          heading: sample?.bearing,
        ),
        session.recipients,
      );
      if (!ref.mounted) {
        return;
      }
      _lastPublishedAt = now;
      _lastPublishedPosition = sample?.position;
      state = state.copyWith(lastPublishedAt: now, clearError: true);
      await _showNotification(session);
    } on AppException catch (error) {
      if (!ref.mounted) {
        return;
      }
      // Keep sharing — a single relay failure should not end the session; the
      // next tick retries and the card surfaces the problem.
      state = state.copyWith(error: error.message);
    }
  }

  Future<void> _send(
    LiveShareBroadcast broadcast,
    List<String> recipients,
  ) async {
    await ref.read(publishLiveShareProvider)(
      broadcast: broadcast,
      recipientPubkeys: recipients,
    );
  }

  void _scheduleExpiry(LiveShareSession session) {
    _expiryTimer?.cancel();
    final Duration left = session.expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      left.isNegative ? Duration.zero : left,
      () => unawaited(stop()),
    );
  }

  Future<void> _showNotification(LiveShareSession session) async {
    final int count = session.recipients.length;
    final String friends = count == 1 ? '1 friend' : '$count friends';
    await ref
        .read(liveShareNotificationsProvider)
        .show(
          title: 'Sharing your live location',
          body:
              'Visible to $friends until ${formatClockTime(session.expiresAt)}.',
        );
  }

  void _teardown() {
    unawaited(_sub?.cancel());
    _sub = null;
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  /// A new random 128-bit session id (hex).
  static String newSessionId() {
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    final StringBuffer buffer = StringBuffer();
    for (final int byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final NotifierProvider<LiveShareController, LiveShareState> liveShareProvider =
    NotifierProvider<LiveShareController, LiveShareState>(
      LiveShareController.new,
    );
