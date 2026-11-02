/// Self-update entities: the version installed on the device, the release a
/// remote manifest advertises, and the outcome of comparing the two.
///
/// Pure Dart (L1) — the wire format (the manifest JSON) lives in `lib/data/`.
library;

/// The app version currently installed on the device.
///
/// Read from the platform package metadata (`package_info_plus`) behind the
/// `AppVersionSource` port.
class AppVersion {
  const AppVersion({required this.versionCode, required this.versionName});

  /// The build number the OS knows the app by — on Android the `versionCode`.
  /// With `--split-per-abi` builds this includes Flutter's ABI offset
  /// (`abi*1000 + pubspec versionCode`), which is exactly what the manifest
  /// advertises and what the system would compare.
  final int versionCode;

  /// The human-readable version, e.g. `1.4.0`.
  final String versionName;

  /// Used before the platform metadata has loaded.
  static const AppVersion unknown = AppVersion(versionCode: 0, versionName: '');

  bool get isKnown => versionCode > 0 || versionName.isNotEmpty;

  @override
  String toString() =>
      versionName.isEmpty ? '$versionCode' : '$versionName ($versionCode)';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.versionCode == versionCode &&
      other.versionName == versionName;

  @override
  int get hashCode => Object.hash(versionCode, versionName);
}

/// A published release described by the update manifest.
///
/// Every field is external, untrusted input (see `HttpReleaseSource`), so the
/// constructor only accepts already-validated values.
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.sha256,
    this.mandatory = false,
    this.releaseNotes = '',
  });

  /// The release's `versionCode` — the authoritative comparison key.
  final int versionCode;

  /// The release's human-readable version, e.g. `1.4.0`.
  final String versionName;

  /// Where the `.apk` is downloaded from (http/https).
  final Uri apkUrl;

  /// Lower-case hex SHA-256 of the APK, when the manifest carries one.
  final String? sha256;

  /// Whether the user must install this update (no "Later").
  final bool mandatory;

  /// Free-text notes shown in the update prompt (may be empty).
  final String releaseNotes;

  /// The notes split into individual change lines, with any leading bullet
  /// markers stripped — the update prompt lists them one per row.
  List<String> get changes => <String>[
    for (final String line in releaseNotes.split('\n'))
      if (_stripBullet(line).isNotEmpty) _stripBullet(line),
  ];

  /// Whether this release is newer than [installed].
  ///
  /// The `versionCode` decides whenever both sides carry one (it is what the OS
  /// compares, and it accounts for the split-APK ABI offset); otherwise the
  /// dotted [versionName] is compared, so a manifest without codes still works.
  bool isNewerThan(AppVersion installed) {
    if (versionCode > 0 && installed.versionCode > 0) {
      return versionCode > installed.versionCode;
    }
    return compareVersionNames(versionName, installed.versionName) > 0;
  }

  @override
  String toString() =>
      'AppRelease($versionName/$versionCode, mandatory: $mandatory)';
}

/// The outcome of an update check: the installed version plus the latest
/// advertised release (if any).
class UpdateCheck {
  const UpdateCheck({required this.installed, this.latest});

  final AppVersion installed;

  /// The latest published release, or `null` when the manifest carried none.
  final AppRelease? latest;

  bool get updateAvailable => latest != null && latest!.isNewerThan(installed);
}

/// Compares two dotted version names (`1.4.0`).
///
/// Numeric segments compare as numbers, one at a time; a missing segment counts
/// as zero, so `1.4` and `1.4.0` are equal; `+build` metadata is ignored (it
/// does not affect ordering); a non-numeric segment compares as text. Returns a
/// negative number when [a] is older, zero when equal and a positive number when
/// [a] is newer.
int compareVersionNames(String a, String b) {
  final List<String> left = _versionSegments(a);
  final List<String> right = _versionSegments(b);
  final int length = left.length > right.length ? left.length : right.length;
  for (int i = 0; i < length; i++) {
    final int comparison = _compareSegment(
      i < left.length ? left[i] : '',
      i < right.length ? right[i] : '',
    );
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

/// Splits a version into its ordering segments, dropping any `+build` suffix.
List<String> _versionSegments(String version) =>
    version.split('+').first.split(RegExp(r'[.\-]'));

/// Compares one segment; empty segments count as `0`, numerics as numbers,
/// anything else as text.
int _compareSegment(String a, String b) {
  final String left = a.trim().isEmpty ? '0' : a.trim();
  final String right = b.trim().isEmpty ? '0' : b.trim();
  final int? leftNumber = int.tryParse(left);
  final int? rightNumber = int.tryParse(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  return left.compareTo(right);
}

/// Removes a leading bullet marker (`- `, `* `, `• `) from a changelog line.
String _stripBullet(String line) {
  final String trimmed = line.trim();
  for (final String marker in const <String>['- ', '* ', '• ', '-', '*', '•']) {
    if (trimmed.startsWith(marker)) {
      return trimmed.substring(marker.length).trim();
    }
  }
  return trimmed;
}
