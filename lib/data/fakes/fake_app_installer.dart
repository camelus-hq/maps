import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/ports/app_installer.dart';

/// In-memory [AppInstaller] for tests and keyless runs.
///
/// Records every install request; [failure] makes one fail with a typed error.
class FakeAppInstaller implements AppInstaller {
  FakeAppInstaller({this.failure});

  /// When set, [install] throws this instead of succeeding.
  AppException? failure;

  /// Every release this fake was asked to install, in order.
  final List<AppRelease> installs = <AppRelease>[];

  @override
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.5);
    final AppException? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    installs.add(release);
    onProgress?.call(1);
  }
}
