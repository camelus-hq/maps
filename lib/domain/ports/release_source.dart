import '../entities/app_update.dart';

/// Fetches the latest published release from the update manifest.
///
/// The manifest is external, hostile input; an implementation validates every
/// field and either returns `null` (no usable release) or throws a typed
/// `AppException` for a network/parse failure — never a raw error.
abstract interface class ReleaseSource {
  /// The latest published release, or `null` when the manifest advertises none.
  Future<AppRelease?> fetchLatest();
}
