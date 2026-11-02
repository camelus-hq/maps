import 'dart:async';

import 'package:ndk/entities.dart' show RelayBroadcastResponse;
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk_flutter/ndk_flutter.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_location.dart';
import '../../domain/entities/live_share.dart';
import '../../domain/ports/social_service.dart';
import 'live_location_payload.dart';

/// [SocialService] backed by Nostr through the NDK client.
///
/// Live shares are published as NIP-59 gift wraps: the location payload is
/// sealed (kind 13) under the sender's identity and then wrapped (kind 1059)
/// with a fresh, throwaway key pair for each recipient. A relay therefore sees
/// only an opaque envelope addressed to the recipient — the sender, the content
/// and the coordinates are all encrypted end to end.
class NdkSocialService implements SocialService {
  NdkSocialService({
    required this.ndk,
    required this.ndkFlutter,
    List<String> relays = const <String>[],
  }) : _relays = _cleanRelays(relays);

  /// Hard cap on how many friends one set contributes.
  static const int _maxFriends = 500;

  /// The NIP-51 set that holds the friend list (kind 30000, `d = friends`).
  static const String friendsSetName = 'friends';

  /// NIP-51 kind for a categorized people set ("follow set").
  static const int friendsSetKind = Nip51List.kFollowSet;

  /// Timeout for a single broadcast to finish, so a dead relay can't hang a
  /// share forever.
  static const Duration _broadcastTimeout = Duration(seconds: 12);

  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  /// The shared NDK client.
  final Ndk ndk;

  /// The login/widget wrapper (used by the login screen); NDK types stay here.
  final NdkFlutter ndkFlutter;

  final List<String> _relays;

  final StreamController<FriendLocation> _incoming =
      StreamController<FriendLocation>.broadcast();

  NdkResponse? _subscription;
  StreamSubscription<Nip01Event>? _subscriptionSub;
  String? _subscribedFor;
  bool _disposed = false;

  @override
  bool get isLoggedIn => ndk.accounts.isLoggedIn;

  @override
  String? get currentUserPubkey => ndk.accounts.getPublicKey();

  @override
  Stream<String?> get identityChanges async* {
    yield currentUserPubkey;
    yield* ndk.accounts.authStateChanges.map(
      (Account? account) => account?.pubkey,
    );
  }

  @override
  Future<List<Friend>> loadFriends() async {
    final String? me = currentUserPubkey;
    if (me == null) {
      return const <Friend>[];
    }
    try {
      final Nip51Set? set = await _readFriendsSet(me);
      if (set == null) {
        return const <Friend>[];
      }
      final List<String> pubkeys = <String>[];
      for (final Nip51ListElement element in set.pubKeys) {
        final String key = element.value.trim().toLowerCase();
        if (_hexPubkey.hasMatch(key) && !pubkeys.contains(key)) {
          pubkeys.add(key);
          if (pubkeys.length >= _maxFriends) {
            break;
          }
        }
      }
      if (pubkeys.isEmpty) {
        return const <Friend>[];
      }
      final Map<String, Metadata> profiles = await _loadProfiles(pubkeys);
      final List<Friend> friends = <Friend>[];
      for (final String key in pubkeys) {
        final Metadata? profile = profiles[key];
        final String? name = _firstNonEmpty(<String?>[
          profile?.displayName,
          profile?.name,
        ]);
        friends.add(
          Friend(
            pubkey: key,
            displayName: name,
            pictureUrl: _safeUrl(profile?.picture),
          ),
        );
      }
      friends.sort(
        (Friend a, Friend b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return List<Friend>.unmodifiable(friends);
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException('Could not load your friends', cause: error);
    }
  }

  @override
  Future<List<Friend>> loadFollowings() async {
    final String? me = currentUserPubkey;
    if (me == null) {
      return const <Friend>[];
    }
    try {
      final ContactList? list = await ndk.follows.getContactList(
        me,
        idleTimeout: const Duration(seconds: 6),
      );
      final List<String> pubkeys = <String>[];
      for (final String contact in list?.contacts ?? const <String>[]) {
        final String key = contact.trim().toLowerCase();
        if (_hexPubkey.hasMatch(key) && !pubkeys.contains(key)) {
          pubkeys.add(key);
          if (pubkeys.length >= _maxFriends) {
            break;
          }
        }
      }
      if (pubkeys.isEmpty) {
        return const <Friend>[];
      }
      final Map<String, Metadata> profiles = await _loadProfiles(pubkeys);
      final List<Friend> followings = <Friend>[];
      for (final String key in pubkeys) {
        final Metadata? profile = profiles[key];
        followings.add(
          Friend(
            pubkey: key,
            displayName: _firstNonEmpty(<String?>[
              profile?.displayName,
              profile?.name,
            ]),
            pictureUrl: _safeUrl(profile?.picture),
          ),
        );
      }
      followings.sort(
        (Friend a, Friend b) =>
            a.label.toLowerCase().compareTo(b.label.toLowerCase()),
      );
      return List<Friend>.unmodifiable(followings);
    } on AppException {
      rethrow;
    } catch (error) {
      throw NetworkException('Could not load who you follow', cause: error);
    }
  }

  @override
  Future<Friend> resolveProfile(String pubkey) async {
    final String key = _requirePubkey(pubkey);
    try {
      final Map<String, Metadata> profiles = await _loadProfiles(<String>[key]);
      final Metadata? profile = profiles[key];
      return Friend(
        pubkey: key,
        displayName: _firstNonEmpty(<String?>[
          profile?.displayName,
          profile?.name,
        ]),
        pictureUrl: _safeUrl(profile?.picture),
      );
    } catch (_) {
      return Friend(pubkey: key);
    }
  }

  @override
  String? normalizePubkey(String input) {
    String raw = input.trim();
    if (raw.isEmpty || raw.length > 500) {
      return null;
    }
    if (raw.toLowerCase().startsWith('nostr:')) {
      raw = raw.substring('nostr:'.length).trim();
    }
    // A QR code may wrap the key in a URI fragment.
    if (raw.contains('#') && !raw.startsWith('npub')) {
      raw = raw.split('#').last;
    }
    if (raw.toLowerCase().startsWith('npub1')) {
      try {
        final String decoded = Nip19.decode(raw);
        final String key = decoded.trim().toLowerCase();
        return _hexPubkey.hasMatch(key) ? key : null;
      } catch (_) {
        return null;
      }
    }
    final String hex = raw.toLowerCase();
    return _hexPubkey.hasMatch(hex) ? hex : null;
  }

  @override
  String? encodeNpub(String pubkey) {
    final String key = pubkey.trim().toLowerCase();
    if (!_hexPubkey.hasMatch(key)) {
      return null;
    }
    try {
      return Nip19.encodePubKey(key);
    } catch (_) {
      return null;
    }
  }

  /// Reads the user's "friends" NIP-51 set.
  ///
  /// Prefers the shared live-share relays (explicit, auth-capable, reachable
  /// from anywhere) and falls back to the user's own relays through the NDK
  /// lists usecase. Many popular relays either refuse NIP-51 reads for an author
  /// you are not following or demand NIP-42, so a single path is not enough for
  /// the set to be reliably visible.
  Future<Nip51Set?> _readFriendsSet(String me) async {
    final Account? account = ndk.accounts.getLoggedAccount();
    if (_relays.isNotEmpty) {
      try {
        final List<Nip01Event> events = await ndk.requests
            .query(
              name: 'openmaps-friends-set',
              filter: Filter(
                kinds: <int>[friendsSetKind],
                authors: <String>[me],
                tags: <String, List<String>>{
                  '#d': <String>[friendsSetName],
                },
                limit: 1,
              ),
              explicitRelays: _relays,
              auth: account == null ? null : AuthPolicy.allow(account),
              timeout: const Duration(seconds: 8),
            )
            .future;
        Nip01Event? newest;
        for (final Nip01Event event in events) {
          if (event.getDtag() != friendsSetName) {
            continue;
          }
          if (newest == null || newest.createdAt < event.createdAt) {
            newest = event;
          }
        }
        if (newest != null) {
          return await Nip51Set.fromEvent(newest, account?.signer);
        }
      } catch (_) {
        // Fall through to the outbox path below.
      }
    }
    try {
      return await ndk.lists.getSetByName(
        name: friendsSetName,
        kind: friendsSetKind,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addFriend(String pubkey) async {
    final String key = _requirePubkey(pubkey);
    _requireSigner();
    final Set<String> friends = await _currentFriendPubkeys();
    friends.add(key);
    await _writePrivateFriends(friends);
  }

  @override
  Future<void> removeFriend(String pubkey) async {
    final String key = _requirePubkey(pubkey);
    _requireSigner();
    final Set<String> friends = await _currentFriendPubkeys();
    friends.remove(key);
    await _writePrivateFriends(friends);
  }

  /// The friend public keys currently in the set (public **and** private
  /// elements, since older versions of this app wrote them publicly).
  Future<Set<String>> _currentFriendPubkeys() async {
    final String? me = currentUserPubkey;
    if (me == null) {
      return <String>{};
    }
    final Nip51Set? set = await _readFriendsSet(me);
    final Set<String> keys = <String>{};
    for (final Nip51ListElement element
        in set?.pubKeys ?? const <Nip51ListElement>[]) {
      final String key = element.value.trim().toLowerCase();
      if (_hexPubkey.hasMatch(key)) {
        keys.add(key);
      }
    }
    return keys;
  }

  /// Rewrites the whole "friends" set with **private** elements.
  ///
  /// The keys live in the NIP-44 encrypted content of the set event, so a relay
  /// (or anyone reading it) sees that a set named "friends" exists — never who
  /// is in it. Because the write is a full rewrite, an older set whose keys were
  /// public is migrated to private on the first edit.
  Future<void> _writePrivateFriends(Set<String> pubkeys) async {
    final String? me = currentUserPubkey;
    final Account? account = ndk.accounts.getLoggedAccount();
    if (me == null || account == null || !account.signer.canSign()) {
      throw const ValidationException('Sign in to change your friends');
    }
    final List<String> keys =
        pubkeys.where(_hexPubkey.hasMatch).take(_maxFriends).toList()..sort();
    final Nip51Set set = Nip51Set(
      name: friendsSetName,
      pubKey: me,
      kind: friendsSetKind,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      elements: <Nip51ListElement>[
        for (final String key in keys)
          Nip51ListElement(tag: Nip51List.kPubkey, value: key, private: true),
      ],
    );
    try {
      await ndk.lists.setCompleteSet(
        set: set,
        kind: friendsSetKind,
        // The shared relay set, so this app (and any other client using those
        // relays) can read the set back; the user's own relays are often
        // unreachable or auth-gated for NIP-51 reads.
        specificRelays: _relays.isEmpty ? null : _relays,
      );
    } catch (error) {
      throw NetworkException(
        'Could not update your friends list',
        cause: error,
      );
    }
  }

  /// Validates a friend public key, normalising case.
  String _requirePubkey(String pubkey) {
    final String key = pubkey.trim().toLowerCase();
    if (!_hexPubkey.hasMatch(key)) {
      throw const ValidationException('That does not look like a public key');
    }
    return key;
  }

  /// Ensures a signing identity exists before writing to the network.
  void _requireSigner() {
    final Account? account = ndk.accounts.getLoggedAccount();
    if (account == null || !account.signer.canSign()) {
      throw const ValidationException('Sign in to change your friends');
    }
  }

  @override
  Future<void> publishLiveShare({
    required LiveShareBroadcast broadcast,
    required List<String> recipientPubkeys,
  }) async {
    final String? me = currentUserPubkey;
    final Account? account = ndk.accounts.getLoggedAccount();
    if (me == null || account == null || !account.signer.canSign()) {
      throw const ValidationException(
        'Sign in with a key so your location can be encrypted to your friends.',
      );
    }
    final List<String> recipients = _cleanPubkeys(recipientPubkeys);
    if (recipients.isEmpty) {
      throw const ValidationException(
        'Select at least one friend to share with',
      );
    }
    final String content = LiveLocationPayload.encode(broadcast);
    final Nip01Event rumor;
    try {
      rumor = await ndk.giftWrap.createRumor(
        customPubkey: me,
        kind: LiveLocationPayload.rumorKind,
        content: content,
        tags: <List<String>>[
          for (final String recipient in recipients) <String>['p', recipient],
          <String>['t', LiveLocationPayload.featureTag],
          <String>['d', broadcast.sessionId],
        ],
      );
    } catch (error) {
      throw UnknownException(
        'Could not prepare your location share',
        cause: error,
      );
    }
    bool delivered = false;
    Object? lastError;
    for (final String recipient in recipients) {
      try {
        final Nip01Event wrap = await ndk.giftWrap.toGiftWrap(
          rumor: rumor,
          recipientPubkey: recipient,
        );
        final List<RelayBroadcastResponse> responses = await ndk.broadcast
            .broadcast(
              nostrEvent: wrap,
              // Null relays = Nostr outbox routing: publish where the
              // recipient can actually read it.
              specificRelays: _relays.isEmpty ? null : _relays,
              auth: AuthPolicy.allow(account),
            )
            .broadcastDoneFuture
            .timeout(
              _broadcastTimeout,
              onTimeout: () => const <RelayBroadcastResponse>[],
            );
        if (responses.any(
          (RelayBroadcastResponse response) => response.broadcastSuccessful,
        )) {
          delivered = true;
        }
      } catch (error) {
        lastError = error;
      }
    }
    if (!delivered) {
      throw NetworkException(
        'Could not reach the relay network. Check your connection and try again.',
        cause: lastError,
      );
    }
  }

  @override
  Stream<FriendLocation> watchFriendLocations() {
    final String? me = currentUserPubkey;
    if (me == null) {
      _closeSubscription();
      _subscribedFor = null;
      return _incoming.stream;
    }
    if (_subscribedFor != me) {
      _subscribedFor = me;
      _openSubscription(me);
    }
    return _incoming.stream;
  }

  @override
  Future<void> stopWatching() async {
    _subscribedFor = null;
    _closeSubscription();
  }

  @override
  Future<void> sendDirectMessage({
    required String recipientPubkey,
    required String text,
  }) async {
    final String recipient = recipientPubkey.trim().toLowerCase();
    final String message = text.trim();
    if (!_hexPubkey.hasMatch(recipient)) {
      throw const ValidationException('Unknown recipient');
    }
    if (message.isEmpty) {
      throw const ValidationException('Type a message first');
    }
    if (message.length > 4000) {
      throw const ValidationException('Message is too long');
    }
    try {
      await ndk.dms.sendMessage(recipientPubKey: recipient, content: message);
    } catch (error) {
      throw NetworkException(
        'Could not send the message — this friend may not have direct '
        'messages set up yet.',
        cause: error,
      );
    }
  }

  @override
  Future<void> signInWithPrivateKey(String privateKey) async {
    final String raw = privateKey.trim();
    if (raw.isEmpty) {
      throw const ValidationException('Enter your private key');
    }
    final String hex;
    try {
      hex = raw.startsWith('nsec1') ? Nip19.decode(raw) : raw.toLowerCase();
    } catch (error) {
      throw ValidationException(
        'That does not look like a valid key',
        cause: error,
      );
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw const ValidationException('That does not look like a valid key');
    }
    try {
      if (ndk.accounts.isLoggedIn) {
        ndk.accounts.logout();
      }
      ndk.accounts.loginPrivateKey(
        pubkey: Bip340.getPublicKey(hex),
        privkey: hex,
      );
      await ndkFlutter.saveAccountsState();
    } catch (error) {
      throw UnknownException('Could not sign in', cause: error);
    }
  }

  @override
  Future<void> logout() async {
    await stopWatching();
    try {
      ndk.accounts.logout();
      await ndkFlutter.saveAccountsState();
    } catch (_) {
      // Nothing persisted yet; signing out is still done in memory.
    }
  }

  /// Releases the subscription and the incoming stream (wired to
  /// `ref.onDispose` at the composition root).
  Future<void> dispose() async {
    _disposed = true;
    _closeSubscription();
    await _incoming.close();
  }

  void _openSubscription(String me) {
    final Account? account = ndk.accounts.getLoggedAccount();
    _closeSubscription();
    try {
      final NdkResponse response = ndk.requests.subscription(
        name: 'openmaps-live-location',
        filter: Filter(
          kinds: <int>[GiftWrap.kGiftWrapEventkind],
          pTags: <String>[me],
        ),
        explicitRelays: _relays.isEmpty ? null : _relays,
        desiredCoverage: _relays.isEmpty ? null : _relays.length,
        cacheRead: false,
        cacheWrite: false,
        auth: account == null ? null : AuthPolicy.allow(account),
      );
      _subscription = response;
      _subscriptionSub = response.stream.listen(
        _onWrapped,
        onError: (Object _) {
          // A relay dropping mid-subscription must not take the app down; the
          // next update reconnects.
        },
      );
    } catch (_) {
      // A failed subscription just means no incoming shares until the next
      // identity change; the app keeps working.
    }
  }

  void _closeSubscription() {
    final StreamSubscription<Nip01Event>? sub = _subscriptionSub;
    _subscriptionSub = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    final NdkResponse? response = _subscription;
    _subscription = null;
    if (response != null) {
      unawaited(
        ndk.requests.closeSubscription(
          response.requestId,
          debugLabel: 'openmaps-live-location',
        ),
      );
    }
  }

  Future<void> _onWrapped(Nip01Event event) async {
    if (_disposed || event.kind != GiftWrap.kGiftWrapEventkind) {
      return;
    }
    try {
      final Nip01Event rumor = await ndk.giftWrap.fromGiftWrap(giftWrap: event);
      if (rumor.kind != LiveLocationPayload.rumorKind) {
        return;
      }
      final String sender = rumor.pubKey.trim().toLowerCase();
      if (!_hexPubkey.hasMatch(sender) || sender == currentUserPubkey) {
        return;
      }
      final LiveLocationPayload? payload = LiveLocationPayload.decode(
        rumor.content,
      );
      if (payload == null) {
        return;
      }
      if (!_incoming.isClosed) {
        _incoming.add(
          FriendLocation(
            pubkey: sender,
            position: payload.position,
            updatedAt: payload.sampledAt,
            expiresAt: payload.expiresAt,
            ended: payload.isStop,
            accuracyMeters: payload.accuracyMeters,
            heading: payload.heading,
            displayName: payload.displayName,
            sessionId: payload.sessionId,
          ),
        );
      }
    } catch (_) {
      // Not addressed to us, undecryptable, or malformed: ignore.
    }
  }

  Future<Map<String, Metadata>> _loadProfiles(List<String> pubkeys) async {
    if (pubkeys.isEmpty) {
      return const <String, Metadata>{};
    }
    try {
      // Profiles are published everywhere, so ask a couple of well-connected
      // indexes on top of the live-share relays rather than only the user's
      // outbox (which the contact-list lookup already covers).
      final List<Nip01Event> events = await ndk.requests
          .query(
            name: 'openmaps-profiles',
            filter: Filter(
              kinds: <int>[Metadata.kKind],
              authors: pubkeys,
              limit: pubkeys.length,
            ),
            explicitRelays: _profileRelays,
            cacheRead: true,
            cacheWrite: true,
            timeout: const Duration(seconds: 8),
          )
          .future;
      final Map<String, Metadata> profiles = <String, Metadata>{};
      for (final Nip01Event event in events) {
        try {
          final Metadata metadata = Metadata.fromEvent(event);
          if (metadata.pubKey.isNotEmpty) {
            profiles[metadata.pubKey] = metadata;
          }
        } catch (_) {
          // A malformed profile event is skipped, not fatal.
        }
      }
      return profiles;
    } catch (_) {
      // Profile names are a nicety; the key still identifies the friend.
      return const <String, Metadata>{};
    }
  }

  /// Relays queried for profile (kind 0) metadata.
  List<String> get _profileRelays {
    final List<String> relays = <String>[..._relays];
    for (final String extra in const <String>[
      'wss://purplepag.es',
      'wss://relay.primal.net',
    ]) {
      if (!relays.contains(extra)) {
        relays.add(extra);
      }
    }
    return relays;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      final String? trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static String? _safeUrl(String? raw) {
    final String? trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.length > 2048) {
      return null;
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return uri.toString();
  }

  static List<String> _cleanPubkeys(List<String> pubkeys) {
    final List<String> cleaned = <String>[];
    for (final String raw in pubkeys) {
      final String key = raw.trim().toLowerCase();
      if (_hexPubkey.hasMatch(key) && !cleaned.contains(key)) {
        cleaned.add(key);
      }
    }
    return cleaned;
  }

  static List<String> _cleanRelays(List<String> relays) {
    final List<String> cleaned = <String>[];
    for (final String raw in relays) {
      final String relay = raw.trim();
      if ((relay.startsWith('wss://') || relay.startsWith('ws://')) &&
          !cleaned.contains(relay)) {
        cleaned.add(relay);
      }
    }
    return cleaned;
  }
}
