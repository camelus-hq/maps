import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/entities/app_update.dart';
import '../../domain/ports/app_version_source.dart';

/// [AppVersionSource] backed by the platform package metadata
/// (`package_info_plus`).
///
/// Reading the metadata can fail on an unsupported platform; that degrades to
/// [AppVersion.unknown] rather than throwing, so a missing plugin never blocks
/// the update check.
class PackageInfoAppVersionSource implements AppVersionSource {
  const PackageInfoAppVersionSource();

  @override
  Future<AppVersion> current() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      // On Android `buildNumber` is the (long) versionCode — with split-APK
      // builds that already includes Flutter's ABI offset, which is what the
      // manifest advertises.
      return AppVersion(
        versionCode: int.tryParse(info.buildNumber.trim()) ?? 0,
        versionName: info.version.trim(),
      );
    } catch (_) {
      return AppVersion.unknown;
    }
  }
}
