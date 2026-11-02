import '../entities/app_update.dart';

/// Downloads a release APK and hands it to the operating system's installer.
///
/// Kept behind a port because installing an APK is a platform action (an
/// Android install intent). Implementations download to a private location,
/// verify the manifest's checksum when present, and surface failures as typed
/// `AppException`s — notably [UnsupportedException] when in-app install is not
/// available on the current platform/build, so the UI can offer the download
/// link instead.
abstract interface class AppInstaller {
  /// Downloads [release] and opens the installer.
  ///
  /// [onProgress] is called with a `0..1` fraction while downloading (the
  /// fraction may stay at `0` when the server sends no `Content-Length`).
  Future<void> install(
    AppRelease release, {
    void Function(double progress)? onProgress,
  });
}
