import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../domain/ports/feedback_service.dart';

/// In-memory [FeedbackService] so the app runs, and tests run, without relays.
///
/// It records what it was asked to send so a widget/state test can assert the
/// message, the screenshot bytes and the appended context.
class FakeFeedbackService implements FeedbackService {
  FakeFeedbackService({this.signedIn = true});

  /// Whether this fake reports a signed-in identity.
  bool signedIn;

  /// When set, [sendFeedback] throws it (tests).
  AppException? error;

  /// Every feedback message sent (as `message` → screenshot byte count).
  final List<MapEntry<String, int>> sent = <MapEntry<String, int>>[];

  /// The last screenshot handed to [sendFeedback].
  Uint8List? lastScreenshot;

  /// The last context string handed to [sendFeedback].
  String? lastContext;

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<void> sendFeedback({
    required String message,
    required Uint8List screenshot,
    String? context,
  }) async {
    if (!signedIn) {
      throw const ValidationException('Sign in to send feedback');
    }
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    sent.add(MapEntry<String, int>(message, screenshot.length));
    lastScreenshot = screenshot;
    lastContext = context;
  }
}
