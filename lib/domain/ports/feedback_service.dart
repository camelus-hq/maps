import 'dart:typed_data';

/// Delivers in-app feedback to the OpenMaps maintainers over Nostr.
///
/// Implemented in `data/nostr/` (NDK): the message becomes a private NIP-17
/// direct message and the screenshot is AES-GCM encrypted (NIP-17 kind 15,
/// Amethyst-compatible) before it leaves the device, so a relay can read
/// neither the text nor the image. Nothing outside `data/nostr/` knows the wire
/// format; the keyless/test default is an in-memory fake.
abstract interface class FeedbackService {
  /// Whether a Nostr identity is signed in (feedback is signed end to end).
  bool get isSignedIn;

  /// Sends [message] with [screenshot] attached.
  ///
  /// [context] is optional free text (app version, platform) the adapter puts
  /// above the message so a report is actionable without a second question.
  ///
  /// Throws an [AppException] when signed out, no recipient is configured, the
  /// screenshot cannot be encrypted/uploaded, or no relay accepted the message.
  Future<void> sendFeedback({
    required String message,
    required Uint8List screenshot,
    String? context,
  });
}
