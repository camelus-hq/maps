import 'dart:async';
import 'dart:typed_data';

import 'package:ndk/entities.dart' show NdkFile, RelayBroadcastResponse;
import 'package:ndk/ndk.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/ports/feedback_service.dart';

/// [FeedbackService] backed by Nostr through the NDK client.
///
/// A report is delivered as **private NIP-17 direct messages**: the text goes
/// out as a kind-14 rumor and the screenshot as a kind-15 file message whose
/// bytes are **AES-256-GCM encrypted** (a fresh key + 16-byte nonce, the
/// convention Amethyst uses), so the image is unreadable on the Blossom host and
/// on every relay. Only the recipient's key can decrypt it.
///
/// Delivery goes through `ndk.giftWrap` directly (the same path live-location
/// shares take): each rumor is sealed and gift-wrapped (NIP-59) for the
/// recipient with a fresh throwaway key, then broadcast to the configured
/// relays (NDK's outbox routing when none are set). This deliberately avoids the
/// `ndk.dms` usecase, which needs both parties to publish a kind-10050 inbox
/// list and has proven unreliable — the payload is end-to-end encrypted either
/// way.
class NdkFeedbackService implements FeedbackService {
  NdkFeedbackService({
    required this.ndk,
    required this.recipientPubkey,
    // Relays the gift-wrapped messages are broadcast to. The app passes the
    // proven live-share set from `lib/app/di.dart`; this is only the fallback
    // not to accept the gift-wrap broadcast in testing.)
    List<String> relays = const <String>[],
    List<String> blossomServers = const <String>[],
  }) : _relays = _cleanRelays(relays),
       _blossomServers = _cleanServers(blossomServers);

  /// Kind of a NIP-17 text rumor.
  static const int _textKind = 14;

  /// Kind of a NIP-17 encrypted-file rumor.
  static const int _fileKind = 15;

  /// Bounded waits, so a dead relay or a stalled upload can never hang the UI.
  static const Duration _uploadTimeout = Duration(seconds: 20);
  static const Duration _broadcastTimeout = Duration(seconds: 12);

  /// A lowercase-hex public key.
  static final RegExp _hexPubkey = RegExp(r'^[0-9a-f]{64}$');

  final Ndk ndk;

  /// The raw `FEEDBACK_PUBKEY` define (`npub…` or hex).
  final String recipientPubkey;

  final List<String> _relays;
  final List<String> _blossomServers;

  @override
  bool get isSignedIn => ndk.accounts.isLoggedIn;

  @override
  Future<void> sendFeedback({
    required String message,
    required Uint8List screenshot,
    String? context,
  }) async {
    final String? recipient = normalizeRecipientPubkey(recipientPubkey);
    if (recipient == null) {
      throw const UnsupportedException(
        'This build has no feedback recipient configured.',
      );
    }
    final Account? account = ndk.accounts.getLoggedAccount();
    if (account == null || !account.signer.canSign()) {
      throw const ValidationException('Sign in to send feedback');
    }
    final String? me = ndk.accounts.getPublicKey();
    if (me == null) {
      throw const ValidationException('Sign in to send feedback');
    }

    // Encrypt the screenshot before it leaves the device. The metadata (key,
    // nonce and both hashes) will travel only inside the encrypted rumor.
    final Nip17EncryptedFile encrypted;
    try {
      encrypted = await Nip17FileCrypto.encrypt(screenshot);
    } catch (error) {
      throw UnknownException('Could not encrypt the screenshot', cause: error);
    }

    final String url = await _uploadEncrypted(encrypted);
    final Nip17FileMetadata metadata = Nip17FileMetadata.fromEncryptedFile(
      url: Uri.parse(url),
      mimeType: 'image/png',
      encryptedFile: encrypted,
    );

    // The text first, then the image, as two messages in the same thread.
    await _sendMessage(
      me: me,
      account: account,
      recipient: recipient,
      content: _composeText(message, context),
      kind: _textKind,
      extraTags: const <List<String>>[],
    );
    await _sendMessage(
      me: me,
      account: account,
      recipient: recipient,
      content: metadata.url.toString(),
      kind: _fileKind,
      extraTags: metadata.toTags(),
    );
  }

  /// Uploads the ciphertext to Blossom and returns its public URL.
  Future<String> _uploadEncrypted(Nip17EncryptedFile encrypted) async {
    final List<BlobUploadResult> results;
    try {
      results = await ndk.files
          .upload(
            file: NdkFile(
              data: encrypted.ciphertext,
              mimeType: 'application/octet-stream',
              size: encrypted.size,
            ),
            serverUrls: _blossomServers.isEmpty ? null : _blossomServers,
            auth: _blossomAuth,
          )
          .timeout(_uploadTimeout);
    } catch (error) {
      throw NetworkException(
        'Could not upload the screenshot. Check your connection and try again.',
        cause: error,
      );
    }
    final String? url = _firstUploadedUrl(results);
    if (url == null) {
      throw const NetworkException(
        'Could not upload the screenshot. Try again in a moment.',
      );
    }
    return url;
  }

  /// Gift-wraps one NIP-17 rumor for [recipient] and broadcasts the wrap.
  ///
  /// A fresh throwaway key per message hides the sender, and only the recipient
  /// can unwrap it. Throws an [AppException] when the rumor cannot be prepared
  /// or no relay accepted the event.
  Future<void> _sendMessage({
    required String me,
    required Account account,
    required String recipient,
    required String content,
    required int kind,
    required List<List<String>> extraTags,
  }) async {
    final Nip01Event rumor;
    try {
      rumor = await ndk.giftWrap.createRumor(
        customPubkey: me,
        kind: kind,
        content: content,
        tags: <List<String>>[
          <String>['p', recipient],
          ...extraTags,
        ],
      );
    } catch (error) {
      throw UnknownException('Could not prepare your feedback', cause: error);
    }

    bool delivered = false;
    Object? lastError;
    try {
      final Nip01Event wrap = await ndk.giftWrap.toGiftWrap(
        rumor: rumor,
        recipientPubkey: recipient,
      );
      final List<RelayBroadcastResponse> responses = await ndk.broadcast
          .broadcast(
            nostrEvent: wrap,
            specificRelays: _relays.isEmpty ? null : _relays,
            auth: AuthPolicy.allow(account),
          )
          .broadcastDoneFuture
          .timeout(
            _broadcastTimeout,
            onTimeout: () => const <RelayBroadcastResponse>[],
          );
      delivered = responses.any(
        (RelayBroadcastResponse response) => response.broadcastSuccessful,
      );
    } catch (error) {
      lastError = error;
    }
    if (!delivered) {
      throw NetworkException(
        'Could not reach the relay network. Check your connection and try '
        'again.',
        cause: lastError,
      );
    }
  }

  /// The text that travels as the kind-14 message.
  static String _composeText(String message, String? context) {
    final String trimmed = message.trim();
    final String? trimmedContext = context?.trim();
    if (trimmedContext == null || trimmedContext.isEmpty) {
      return trimmed;
    }
    return '$trimmedContext\n\n$trimmed';
  }

  /// The auth policy for Blossom uploads: the signed-in account signs the
  /// kind-24242 event up front (several public servers answer 400, not 401,
  /// without it).
  AuthPolicy? get _blossomAuth {
    final Account? account = ndk.accounts.getLoggedAccount();
    if (account == null || !account.signer.canSign()) {
      return null;
    }
    return AuthPolicy.require(account);
  }

  /// Normalises the `FEEDBACK_PUBKEY` define (`npub1…`, `nostr:npub…` or
  /// 64-char hex) to a lowercase hex public key, or `null` when it is not one.
  /// Pure — no network — so it is unit-testable.
  static String? normalizeRecipientPubkey(String raw) {
    String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (value.toLowerCase().startsWith('nostr:')) {
      value = value.substring('nostr:'.length).trim();
    }
    if (value.toLowerCase().startsWith('npub1')) {
      try {
        final String decoded = Nip19.decode(value).trim().toLowerCase();
        return _hexPubkey.hasMatch(decoded) ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    final String hex = value.toLowerCase();
    return _hexPubkey.hasMatch(hex) ? hex : null;
  }

  static String? _firstUploadedUrl(List<BlobUploadResult> results) {
    for (final BlobUploadResult result in results) {
      final String? url = result.success ? result.descriptor?.url : null;
      if (url != null && url.startsWith('http')) {
        return url;
      }
    }
    return null;
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

  static List<String> _cleanServers(List<String> servers) {
    final List<String> cleaned = <String>[];
    for (final String raw in servers) {
      final String server = raw.trim().replaceAll(RegExp(r'/+$'), '');
      if ((server.startsWith('https://') || server.startsWith('http://')) &&
          !cleaned.contains(server)) {
        cleaned.add(server);
      }
    }
    return cleaned;
  }
}
