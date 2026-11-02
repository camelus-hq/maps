import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/result.dart';
import '../domain/entities/app_update.dart';
import 'ports.dart';
import 'usecases.dart';

/// Where the update check is in its lifecycle.
enum UpdateStatus {
  /// No check has run yet in this session.
  idle,

  /// A check is in flight.
  checking,

  /// A newer release is available.
  available,

  /// The installed version is the latest (or no usable manifest).
  upToDate,

  /// The check failed (network/parse); [UpdateState.error] holds the message.
  error,
}

/// The update flow's state: the installed version, the advertised release and
/// the download/install progress.
class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.idle,
    this.installed = AppVersion.unknown,
    this.release,
    this.skipped = false,
    this.installing = false,
    this.progress = 0,
    this.error,
  });

  final UpdateStatus status;
  final AppVersion installed;

  /// The newer release on offer, or `null` when there is nothing to install.
  final AppRelease? release;

  /// Whether the user declined [release] (persisted; the startup prompt stays
  /// hidden until a newer release appears).
  final bool skipped;

  final bool installing;
  final double progress;

  /// The last failure's message, or `null`.
  final String? error;

  bool get updateAvailable =>
      status == UpdateStatus.available && release != null;

  bool get isMandatory => release?.mandatory ?? false;

  /// Whether the startup prompt should be visible.
  bool get shouldPrompt => updateAvailable && !skipped;

  UpdateState copyWith({
    UpdateStatus? status,
    AppVersion? installed,
    AppRelease? release,
    bool clearRelease = false,
    bool? skipped,
    bool? installing,
    double? progress,
    String? error,
    bool clearError = false,
  }) => UpdateState(
    status: status ?? this.status,
    installed: installed ?? this.installed,
    release: clearRelease ? null : (release ?? this.release),
    skipped: skipped ?? this.skipped,
    installing: installing ?? this.installing,
    progress: progress ?? this.progress,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives the self-update flow: checks the manifest, tracks the declined
/// release, and runs the download + install through the [AppInstaller] port.
///
/// Lives in L3 so the startup prompt, the settings row and the `app.update.*`
/// commands all share one path.
class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() => const UpdateState();

  /// Fetches the manifest and the installed version, updating [state].
  Future<void> check() async {
    if (state.status == UpdateStatus.checking) {
      return;
    }
    state = state.copyWith(status: UpdateStatus.checking, clearError: true);

    final Result<UpdateCheck> result = await ref.read(checkForUpdateProvider)();
    if (!ref.mounted) {
      return;
    }
    final int? skippedCode = await ref
        .read(settingsRepositoryProvider)
        .skippedUpdateVersionCode();
    if (!ref.mounted) {
      return;
    }

    switch (result) {
      case Ok<UpdateCheck>(:final UpdateCheck value):
        final AppRelease? latest = value.latest;
        final bool available = value.updateAvailable && latest != null;
        state = UpdateState(
          status: available ? UpdateStatus.available : UpdateStatus.upToDate,
          installed: value.installed,
          release: available ? latest : null,
          skipped: available && latest.versionCode == skippedCode,
        );
      case Err<UpdateCheck>(:final AppException error):
        state = state.copyWith(
          status: UpdateStatus.error,
          error: error.message,
          clearRelease: true,
        );
    }
  }

  /// Records that the user declined the offered release, so the startup prompt
  /// is not shown for it again (a newer release prompts afresh).
  Future<void> dismissPrompt() async {
    final AppRelease? release = state.release;
    state = state.copyWith(skipped: true);
    if (release != null) {
      await ref
          .read(settingsRepositoryProvider)
          .setSkippedUpdateVersionCode(release.versionCode);
    }
  }

  /// Downloads and installs the offered release.
  Future<void> install() async {
    final AppRelease? release = state.release;
    if (release == null || state.installing) {
      return;
    }
    state = state.copyWith(
      installing: true,
      progress: 0,
      clearError: true,
      skipped: false,
    );
    try {
      await ref
          .read(appInstallerProvider)
          .install(
            release,
            onProgress: (double progress) {
              if (!ref.mounted) {
                return;
              }
              state = state.copyWith(progress: progress);
            },
          );
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(installing: false, progress: 1);
    } on AppException catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(installing: false, error: error.message);
    } catch (_) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        installing: false,
        error: 'The update could not be installed',
      );
    }
  }
}

final NotifierProvider<UpdateController, UpdateState> updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);

/// The version installed on the device, read straight from the platform
/// metadata so the settings screen can show it before any check has run.
final FutureProvider<AppVersion> installedVersionProvider =
    FutureProvider<AppVersion>(
      (Ref ref) => ref.watch(appVersionSourceProvider).current(),
    );
