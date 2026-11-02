import 'dart:async';
import 'dart:math' as math;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_location.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/live_share.dart';
import '../../domain/ports/social_service.dart';

/// In-memory [SocialService] so the app runs, and tests run, without relays.
///
/// It behaves like a signed-in demo identity with a handful of friends and lets
/// tests push incoming shares through [emit].
class FakeSocialService implements SocialService {
  FakeSocialService({
    List<Friend>? friends,
    this.signedIn = true,
    List<FriendLocation>? liveFriends,
    List<Friend>? followings,
  }) : _friends = List<Friend>.of(friends ?? demoFriends),
       _follows = List<Friend>.of(followings ?? demoFollowings) {
    _identityController = StreamController<String?>.broadcast();
    _incoming = StreamController<FriendLocation>.broadcast();
    for (final FriendLocation location
        in liveFriends ?? const <FriendLocation>[]) {
      _live[location.pubkey] = location;
    }
  }

  /// A demo signed-in identity (64 hex chars) used when no real key is set.
  static const String demoUserPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';

  /// The demo friends shown in keyless runs (our own invented people).
  static const List<Friend> demoFriends = <Friend>[
    Friend(
      pubkey:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      displayName: 'Mira',
    ),
    Friend(
      pubkey:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      displayName: 'Timo',
    ),
    Friend(
      pubkey:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      displayName: 'Alex',
    ),
    Friend(
      pubkey:
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      displayName: 'Nia',
    ),
  ];

  /// People the demo identity follows but has not added as friends yet.
  static const List<Friend> demoFollowings = <Friend>[
    Friend(
      pubkey:
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      displayName: 'Robin',
    ),
    Friend(
      pubkey:
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      displayName: 'Sam',
    ),
  ];

  /// A couple of live friends around Berlin so the map has something to show.
  static List<FriendLocation> defaultLiveFriends(DateTime now) {
    final DateTime expiry = now.add(const Duration(minutes: 42));
    return <FriendLocation>[
      FriendLocation(
        pubkey: demoFriends[0].pubkey,
        position: const LatLon(52.5205, 13.4095),
        updatedAt: now.subtract(const Duration(seconds: 20)),
        expiresAt: expiry,
        displayName: 'Mira',
        sessionId: 'demo-mira',
      ),
      FriendLocation(
        pubkey: demoFriends[1].pubkey,
        position: const LatLon(52.5166, 13.4025),
        updatedAt: now.subtract(const Duration(seconds: 45)),
        expiresAt: expiry,
        displayName: 'Timo',
        sessionId: 'demo-timo',
      ),
    ];
  }

  final List<Friend> _friends;

  /// People this fake pretends to follow, offered by [loadFollowings].
  final List<Friend> _follows;

  /// Whether this fake reports a signed-in identity.
  bool signedIn;
  late final StreamController<String?> _identityController;
  late final StreamController<FriendLocation> _incoming;
  final Map<String, FriendLocation> _live = <String, FriendLocation>{};

  /// Every broadcast this fake was asked to publish (newest last).
  final List<LiveShareBroadcast> published = <LiveShareBroadcast>[];

  /// Every recipient set a publish addressed (parallel to [published]).
  final List<List<String>> publishedRecipients = <List<String>>[];

  /// Every direct message this fake sent (recipient, text).
  final List<MapEntry<String, String>> sentMessages =
      <MapEntry<String, String>>[];

  /// The public key [signInWithPrivateKey] was called with.
  String? signedInWithKey;

  /// When set, calls to [publishLiveShare] throw it (tests).
  AppException? publishError;

  @override
  bool get isLoggedIn => signedIn;

  @override
  String? get currentUserPubkey => signedIn ? demoUserPubkey : null;

  @override
  Stream<String?> get identityChanges {
    // A finite stream rather than an endless `async*` generator: it emits the
    // current identity, then follows the controller and ends with it. An
    // `async*` stream that never completes leaves a subscriber dangling (and
    // wedges a test isolate when the fake is disposed mid-subscription).
    late final StreamController<String?> out;
    StreamSubscription<String?>? sub;
    out = StreamController<String?>(
      onListen: () {
        out.add(currentUserPubkey);
        sub = _identityController.stream.listen(
          out.add,
          onError: out.addError,
          onDone: out.close,
        );
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
        if (!out.isClosed) {
          await out.close();
        }
      },
    );
    return out.stream;
  }

  @override
  Future<List<Friend>> loadFriends() async =>
      signedIn ? List<Friend>.unmodifiable(_friends) : const <Friend>[];

  @override
  Future<void> addFriend(String pubkey) async {
    final String key = _validatePubkey(pubkey);
    if (_friends.every((Friend friend) => friend.pubkey != key)) {
      _friends.add(Friend(pubkey: key));
      _sortFriends();
    }
  }

  @override
  Future<void> removeFriend(String pubkey) async {
    final String key = _validatePubkey(pubkey);
    _friends.removeWhere((Friend friend) => friend.pubkey == key);
  }

  @override
  Future<List<Friend>> loadFollowings() async {
    if (!signedIn) {
      return const <Friend>[];
    }
    final List<Friend> followings = <Friend>[
      for (final Friend friend in _follows) friend,
    ];
    followings.sort(
      (Friend a, Friend b) =>
          a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    return List<Friend>.unmodifiable(followings);
  }

  @override
  String? encodeNpub(String pubkey) {
    // The fake cannot do bech32; return a stable placeholder so the "My code"
    // screen has something to render in keyless runs and tests.
    final String key = pubkey.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      return null;
    }
    return 'npub1${key.substring(0, 20)}fake${key.substring(40, 52)}';
  }

  @override
  Future<Friend> resolveProfile(String pubkey) async {
    final String key = _validatePubkey(pubkey);
    for (final Friend friend in _follows) {
      if (friend.pubkey == key) {
        return friend;
      }
    }
    for (final Friend friend in _friends) {
      if (friend.pubkey == key) {
        return friend;
      }
    }
    return Friend(pubkey: key, displayName: 'Friend ${key.substring(0, 4)}');
  }

  @override
  String? normalizePubkey(String input) {
    String raw = input.trim();
    if (raw.toLowerCase().startsWith('nostr:')) {
      raw = raw.substring('nostr:'.length).trim();
    }
    // The fake cannot decode bech32; accept a hex key so tests can exercise the
    // paste path, and mirror the real adapter's rejection of anything else.
    final String hex = raw.toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(hex) ? hex : null;
  }

  void _sortFriends() {
    _friends.sort(
      (Friend a, Friend b) =>
          a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
  }

  String _validatePubkey(String pubkey) {
    final String key = pubkey.trim().toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
      throw const ValidationException('That does not look like a public key');
    }
    if (!signedIn) {
      throw const ValidationException('Sign in to change your friends');
    }
    return key;
  }

  @override
  Future<void> publishLiveShare({
    required LiveShareBroadcast broadcast,
    required List<String> recipientPubkeys,
  }) async {
    if (!signedIn) {
      throw const ValidationException('Sign in to share your location');
    }
    final AppException? error = publishError;
    if (error != null) {
      throw error;
    }
    published.add(broadcast);
    publishedRecipients.add(List<String>.unmodifiable(recipientPubkeys));
  }

  @override
  Stream<FriendLocation> watchFriendLocations() {
    // Replay the friends that are already live so the map fills immediately.
    for (final FriendLocation location in _live.values) {
      scheduleMicrotask(() {
        if (!_incoming.isClosed) {
          _incoming.add(location);
        }
      });
    }
    return _incoming.stream;
  }

  @override
  Future<void> stopWatching() async {}

  @override
  Future<void> sendDirectMessage({
    required String recipientPubkey,
    required String text,
  }) async {
    if (!signedIn) {
      throw const ValidationException('Sign in to send a message');
    }
    sentMessages.add(MapEntry<String, String>(recipientPubkey, text));
  }

  @override
  Future<void> signInWithPrivateKey(String privateKey) async {
    if (privateKey.trim().isEmpty) {
      throw const ValidationException('Enter your private key');
    }
    signedInWithKey = privateKey.trim();
    signedIn = true;
    _identityController.add(currentUserPubkey);
  }

  @override
  Future<void> logout() async {
    signedIn = false;
    _live.clear();
    _identityController.add(null);
  }

  /// Pushes a friend share (or an ended one) to the incoming stream.
  void emit(FriendLocation location) {
    if (location.ended) {
      _live.remove(location.pubkey);
    } else {
      _live[location.pubkey] = location;
    }
    if (!_incoming.isClosed) {
      _incoming.add(location);
    }
  }

  /// Seeds a live friend at a deterministic offset from [near] (demo/testing).
  FriendLocation seedLiveFriend({
    required Friend friend,
    required LatLon near,
    required DateTime now,
    Duration duration = const Duration(minutes: 30),
    int index = 0,
  }) {
    final double offset = 0.002 + index * 0.001;
    final FriendLocation location = FriendLocation(
      pubkey: friend.pubkey,
      position: LatLon(
        near.latitude + math.sin(index + 1) * offset,
        near.longitude + math.cos(index + 1) * offset,
      ),
      updatedAt: now,
      expiresAt: now.add(duration),
      displayName: friend.displayName,
      sessionId: 'seed-$index',
    );
    emit(location);
    return location;
  }

  /// Releases the stream controllers (tests).
  ///
  /// Idempotent and non-blocking: closing while a provider is still listening
  /// must not leave a pending completion behind.
  Future<void> dispose() async {
    if (!_identityController.isClosed) {
      unawaited(_identityController.close());
    }
    if (!_incoming.isClosed) {
      unawaited(_incoming.close());
    }
  }
}
