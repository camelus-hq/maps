import '../../domain/entities/app_update.dart';
import '../../domain/ports/app_version_source.dart';

/// In-memory [AppVersionSource] for tests and keyless runs.
class FakeAppVersionSource implements AppVersionSource {
  FakeAppVersionSource({
    this.version = const AppVersion(versionCode: 1, versionName: '0.1.0'),
  });

  AppVersion version;

  @override
  Future<AppVersion> current() async => version;
}
