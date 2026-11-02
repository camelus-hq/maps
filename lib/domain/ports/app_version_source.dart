import '../entities/app_update.dart';

/// Reads the app version installed on the device (platform package metadata).
///
/// A thin port so nothing in the domain or UI depends on a specific plugin;
/// the keyless/test default is a `FakeAppVersionSource` and `lib/app/di.dart`
/// wires the real one.
abstract interface class AppVersionSource {
  /// The installed version, or [AppVersion.unknown] when it cannot be read.
  Future<AppVersion> current();
}
