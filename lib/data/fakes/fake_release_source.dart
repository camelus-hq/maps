import '../../core/errors/app_exception.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/ports/release_source.dart';

/// In-memory [ReleaseSource] for tests and keyless runs.
///
/// The default advertises **no** release, so a keyless app (and every golden)
/// never shows an update prompt. A test seeds one with [release] or makes the
/// check fail with [failure].
class FakeReleaseSource implements ReleaseSource {
  FakeReleaseSource({this.release, this.failure});

  /// The release advertised by the manifest, or `null` for "no update".
  AppRelease? release;

  /// When set, [fetchLatest] throws this instead of returning [release].
  AppException? failure;

  /// How many times the manifest was fetched.
  int fetches = 0;

  @override
  Future<AppRelease?> fetchLatest() async {
    fetches++;
    final AppException? failure = this.failure;
    if (failure != null) {
      throw failure;
    }
    return release;
  }
}
