import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../ports/feedback_service.dart';

/// Validates a feedback report and hands it to the [FeedbackService].
///
/// The message rules live here (not in the widget) so the screen, the alpha
/// banner and the control channel share one behaviour: a non-empty, bounded
/// message and a screenshot that is actually a PNG.
class SendFeedback {
  const SendFeedback(this._service);

  final FeedbackService _service;

  /// Longest feedback message we accept, in characters. Comfortably under the
  /// NIP-17 text limit while leaving room for the appended context.
  static const int maxMessageLength = 4000;

  /// Smallest screenshot we will send — anything shorter than a PNG signature is
  /// not an image.
  static const int _minScreenshotBytes = 8;

  Future<void> call({
    required String message,
    required Uint8List screenshot,
    String? context,
  }) async {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Tell us what happened first');
    }
    if (trimmed.length > maxMessageLength) {
      throw const ValidationException('Your feedback is too long');
    }
    if (screenshot.length < _minScreenshotBytes) {
      throw const ValidationException('The screenshot could not be captured');
    }
    if (!_service.isSignedIn) {
      throw const ValidationException('Sign in to send feedback');
    }
    final String? trimmedContext = context?.trim();
    await _service.sendFeedback(
      message: trimmed,
      screenshot: screenshot,
      context: (trimmedContext == null || trimmedContext.isEmpty)
          ? null
          : trimmedContext,
    );
  }
}
