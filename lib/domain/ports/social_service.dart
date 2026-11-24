import 'dart:typed_data';

import '../entities/friend.dart';
import '../entities/friend_location.dart';
import '../entities/live_share.dart';
import '../entities/push.dart';
import '../entities/user_profile.dart';
import '../entities/user_relay_lists.dart';

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
  ///
  /// A session **start** and **stop** are published as stored gift wraps
  /// (kind `1059`) so the push server can forward them to a closed app; the
  /// recurring **updates** are ephemeral gift wraps (kind `21059`) that relays
  /// do not store and the server never forwards, so they reach only a listening
  /// app.
  Future<void> publishLiveShare({
    required LiveShareBroadcast broadcast,
    required List<String> recipientPubkeys,
  });

  /// Decrypted live-location updates addressed to the signed-in user.
  ///
  /// Malformed, unsigned, wrongly-addressed or unrelated gift wraps are dropped
  /// silently — the stream only ever carries trustworthy [FriendLocation]s.
  Stream<FriendLocation> watchFriendLocations();

  /// Decrypted gift wraps the app has received on its **own** relay
  /// subscription, for the notification bridge.
  ///
  /// While the app is in the foreground the push server pauses forwarding (the
  /// app already has these), so the app surfaces them itself: a live-share
  /// **start** or a direct message raises a notification. Carries every
  /// decrypted rumor — the consumer decides which kinds are worth surfacing.
  Stream<DecryptedPushEvent> get incomingPushes;

  /// Closes the incoming subscription opened by [watchFriendLocations].
  Future<void> stopWatching();

  /// Sends a private (NIP-17 gift-wrapped) text message to [recipientPubkey].
  Future<void> sendDirectMessage({
    required String recipientPubkey,
    required String text,
  });

  /// Signs an arbitrary event with the signed-in identity and returns its JSON.
  ///
  /// Used by push registration, which must prove ownership of the public key to
  /// the notification server. Returns `null` when nobody is signed in.
  Future<String?> signEvent({
    required int kind,
    required List<List<String>> tags,
    String content,
  });

  /// Decrypts a push gift wrap (as forwarded by the push server) into the event
  /// it carries, or `null` when it cannot be decrypted or nobody is signed in.
  ///
  /// Malformed, unsigned or wrongly-addressed wraps are dropped silently.
  Future<DecryptedPushEvent?> decryptPushEvent(String encryptedEventJson);

  /// Signs in with a raw private key (`nsec…` or 64-char hex). Agents and the
  /// login screen use this; the interactive widget path goes through NDK.
  Future<void> signInWithPrivateKey(String privateKey);

  /// Whether this platform can sign in through a NIP-55 external signer app
  /// (Android only).
  bool get supportsSignerApp;

  /// Signs in through a NIP-55 external signer app.
  ///
  /// Throws an [AppException] when no signer is installed, the user cancels, or
  /// the platform does not support it.
  Future<void> signInWithExternalSigner();

  /// Connects to a NIP-46 remote signer ("bunker") from a `bunker://` URL.
  ///
  /// [onAuthUrl] is called when the bunker asks the user to approve the
  /// connection at an HTTP URL, so the UI can offer to open it.
  Future<void> signInWithBunker(
    String bunkerUrl, {
    void Function(String authUrl)? onAuthUrl,
  });

  /// Creates a brand-new identity, signs in with it, and returns its **private
  /// key** as a bech32 `nsec…` string so the sign-up flow can show it for
  /// backup.
  ///
  /// The caller must never send this value over the control channel or any
  /// other transport (AGENTS.md: secrets never leave the device).
  Future<String> createAccount();

  /// Loads the signed-in user's own profile ([UserProfile]); empty fields when
  /// nothing is published yet.
  Future<UserProfile> loadOwnProfile();

  /// Uploads a profile picture to a Blossom server and returns its public URL.
  Future<String> uploadProfilePicture({
    required Uint8List data,
    required String mimeType,
  });

  /// Publishes the signed-in user's kind-0 profile metadata.
  Future<void> publishProfile(UserProfile profile);

  /// Loads the signed-in user's NIP-65 and NIP-17 DM relay lists.
  Future<UserRelays> loadRelays();

  /// Publishes the user's relay lists (NIP-65 kind 10002 and NIP-17 kind
  /// 10050). Both lists must have at least one relay.
  Future<void> publishRelays(UserRelays relays);

  /// Signs out of the current identity and stops watching.
  Future<void> logout();
}
