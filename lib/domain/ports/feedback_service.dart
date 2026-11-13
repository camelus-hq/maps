import 'dart:typed_data';

/// Delivers in-app feedback to the OpenMaps maintainers over Nostr.
///
/// Implemented in `data/nostr/` (NDK): the message becomes a private NIP-17
/// direct message and the screenshot is AES-GCM encrypted (NIP-17 kind 15,
/// Amethyst-compatible) before it leaves the device, so a relay can read
/// neither the text nor the image. Nothing outside `data/nostr/` knows the wire
/// format; the keyless/test default is an in-memory fake.
///
/// A report is signed as the **signed-in user** when there is one, and
/// otherwise as the app's persistent **anonymous identity** (see
/// `AnonymousIdentity`), so feedback can be sent without an account.
abstract interface class FeedbackService {
  /// Whether a user *account* is signed in.
  ///
  /// This is not a gate on sending: when it is `false` a report goes out from
  /// the app's persistent anonymous identity instead.
  bool get isSignedIn;

  /// The public key a report will be sent from: the signed-in account when
  /// there is one, otherwise the anonymous identity. `null` only when neither
  /// is available (feedback then cannot be sent).
  Future<String?> senderPubkey();

  /// Sends [message] with [screenshot] attached.
  ///
  /// [context] is optional free text (app version, platform) the adapter puts
  /// above the message so a report is actionable without a second question.
  ///
  /// Throws an [AppException] when no recipient is configured, no signing
  /// identity is available, the screenshot cannot be encrypted/uploaded, or no
  /// relay accepted the message.
  Future<void> sendFeedback({
    required String message,
    required Uint8List screenshot,
    String? context,
  });
}
