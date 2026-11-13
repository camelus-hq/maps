import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../domain/entities/app_update.dart';
import 'update.dart';
import 'usecases.dart';

/// Where a feedback report is in its lifecycle.
enum FeedbackStatus {
  /// Nothing sent yet in this session (or the composer was reopened).
  idle,

  /// An upload/publish is in flight.
  sending,

  /// The report was accepted by at least one relay.
  sent,
}

/// The feedback flow's state: the send status and the last failure.
class FeedbackState {
  const FeedbackState({this.status = FeedbackStatus.idle, this.error});

  final FeedbackStatus status;

  /// A user-readable failure from the last attempt, or `null`.
  final String? error;

  bool get isSending => status == FeedbackStatus.sending;

  bool get isSent => status == FeedbackStatus.sent;

  FeedbackState copyWith({
    FeedbackStatus? status,
    String? error,
    bool clearError = false,
  }) => FeedbackState(
    status: status ?? this.status,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives sending an in-app feedback report: the validation/side effects live in
/// [SendFeedback], the platform context (app version, platform) is assembled
/// here, and the widget only renders [FeedbackState].
class FeedbackController extends Notifier<FeedbackState> {
  @override
  FeedbackState build() => const FeedbackState();

  /// Sends [message] with [screenshot] attached, moving through
  /// [FeedbackStatus.sending] to [FeedbackStatus.sent] (or back to `idle` with
  /// an [error]).
  Future<void> send({
    required String message,
    required Uint8List screenshot,
  }) async {
    if (state.isSending) {
      return;
    }
    state = state.copyWith(status: FeedbackStatus.sending, clearError: true);
    final String context = await _contextLine();
    if (!ref.mounted) {
      return;
    }
    try {
      await ref.read(sendFeedbackProvider)(
        message: message,
        screenshot: screenshot,
        context: context,
      );
      if (!ref.mounted) {
        return;
      }
      state = const FeedbackState(status: FeedbackStatus.sent);
    } on AppException catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = FeedbackState(status: FeedbackStatus.idle, error: error.message);
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = const FeedbackState(
        status: FeedbackStatus.idle,
        error: 'Could not send your feedback',
      );
    }
  }

  /// Clears a previous `sent`/error result (when the screen reopens).
  void reset() => state = const FeedbackState();

  /// The line prepended to the report so a message is actionable on its own.
  Future<String> _contextLine() async {
    AppVersion version = AppVersion.unknown;
    try {
      version = await ref
          .read(installedVersionProvider.future)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // The installed version is a nicety; unknown is fine.
    }
    final String platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final String versionText = version.isKnown
        ? '${version.versionName} (${version.versionCode})'
        : 'unknown';
    return 'OpenMaps $versionText · $platform';
  }
}

final NotifierProvider<FeedbackController, FeedbackState>
feedbackControllerProvider =
    NotifierProvider<FeedbackController, FeedbackState>(FeedbackController.new);
