import 'dart:typed_data';

import '../../core/errors/app_exception.dart';
import '../../domain/ports/feedback_service.dart';

/// In-memory [FeedbackService] so the app runs, and tests run, without relays.
///
/// It records what it was asked to send so a widget/state test can assert the
/// message, the screenshot bytes and the appended context. Like the real
/// adapter it sends whether or not a user is signed in; [signedIn] only selects
/// the [senderPubkey] it reports.
class FakeFeedbackService implements FeedbackService {
  FakeFeedbackService({this.signedIn = true, this.senderPubkeyOverride});

  /// Whether this fake reports a signed-in user account.
  bool signedIn;

  /// When set, the key [senderPubkey] reports (tests).
  String? senderPubkeyOverride;

  /// When set, [sendFeedback] throws it (tests).
  AppException? error;

  /// Every feedback message sent (as `message` → screenshot byte count).
  final List<MapEntry<String, int>> sent = <MapEntry<String, int>>[];

  /// The last screenshot handed to [sendFeedback].
  Uint8List? lastScreenshot;

  /// The last context string handed to [sendFeedback].
  String? lastContext;

  /// The demo key reported while signed in.
  static const String userPubkey =
      '1111111111111111111111111111111111111111111111111111111111111111';

  /// The demo anonymous key reported while signed out.
  static const String anonymousPubkey =
      '2222222222222222222222222222222222222222222222222222222222222222';

  @override
  bool get isSignedIn => signedIn;

  @override
  Future<String?> senderPubkey() async =>
      senderPubkeyOverride ?? (signedIn ? userPubkey : anonymousPubkey);

  @override
  Future<void> sendFeedback({
    required String message,
    required Uint8List screenshot,
    String? context,
  }) async {
    final AppException? failure = error;
    if (failure != null) {
      throw failure;
    }
    sent.add(MapEntry<String, int>(message, screenshot.length));
    lastScreenshot = screenshot;
    lastContext = context;
  }
}
