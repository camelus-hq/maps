import '../entities/friend.dart';
import '../entities/friend_location.dart';
import '../entities/live_share.dart';

/// Publishes and receives live location over Nostr.
///
/// Implemented in `data/nostr/` with the NDK client (NIP-59 gift-wrap encrypted
/// events) and by an in-memory fake for tests and keyless runs. Nothing outside
/// `data/nostr/` knows about NDK or the wire format.
abstract interface class SocialService {
  /// Whether a Nostr identity is signed in.
  bool get isLoggedIn;

  /// The signed-in user's public key (lowercase hex), or `null`.
  String? get currentUserPubkey;

  /// Emits the signed-in public key whenever the identity changes (login,
  /// logout, account switch). Emits the current value on subscription.
  Stream<String?> get identityChanges;

  /// Loads the user's friends from their **"friends" set** (NIP-51 kind 30000,
  /// `d = friends`) with profile names where known. Returns an empty list when
  /// signed out or when the set does not exist yet — friends are only ever the
  /// people the user deliberately added.
  ///
  /// The set is **private**: friend keys live in its NIP-44 encrypted content,
  /// so relays never learn who the user's friends are.
  Future<List<Friend>> loadFriends();

  /// Loads the people the user follows (their NIP-02 contact list, kind 3) with
  /// profile names where known, so the friends screen can offer them to add.
  Future<List<Friend>> loadFollowings();

  /// Adds [pubkey] to the user's **private "friends" set** (NIP-51 kind 30000,
  /// `d = friends`, keys encrypted in the event content), creating the set when
  /// it does not exist yet.
  Future<void> addFriend(String pubkey);

  /// Removes [pubkey] from the user's private "friends" set.
  Future<void> removeFriend(String pubkey);

  /// Normalises user input to a hex public key. Accepts an `npub1…` key, an
  /// optional `nostr:` prefix, or a 64-character hex key. Returns `null` when
  /// the input is not a public key (pure parsing — no network).
  String? normalizePubkey(String input);

  /// Encodes a hex public key as an `npub1…` bech32 string (the form a friend's
  /// scanner expects), or `null` when the key is not valid hex. Pure — no
  /// network.
  String? encodeNpub(String pubkey);

  /// Resolves a profile (display name + picture) for an unknown public key so
  /// an added friend is labelled before the next full refresh.
  Future<Friend> resolveProfile(String pubkey);

  /// Gift-wrap encrypts [broadcast] to each of [recipientPubkeys] and publishes
  /// it. Throws an [AppException] when nobody is signed in, no recipient is
  /// selected, or no relay accepted the event.
  Future<void> publishLiveShare({
    required LiveShareBroadcast broadcast,
    required List<String> recipientPubkeys,
  });

  /// Decrypted live-location updates addressed to the signed-in user.
  ///
  /// Malformed, unsigned, wrongly-addressed or unrelated gift wraps are dropped
  /// silently — the stream only ever carries trustworthy [FriendLocation]s.
  Stream<FriendLocation> watchFriendLocations();

  /// Closes the incoming subscription opened by [watchFriendLocations].
  Future<void> stopWatching();

  /// Sends a private (NIP-17 gift-wrapped) text message to [recipientPubkey].
  Future<void> sendDirectMessage({
    required String recipientPubkey,
    required String text,
  });

  /// Signs in with a raw private key (`nsec…` or 64-char hex). Agents and the
  /// login screen use this; the interactive widget path goes through NDK.
  Future<void> signInWithPrivateKey(String privateKey);

  /// Signs out of the current identity and stops watching.
  Future<void> logout();
}
