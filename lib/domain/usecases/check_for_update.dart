import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../entities/app_update.dart';
import '../ports/app_version_source.dart';
import '../ports/release_source.dart';

/// Reads the installed version and the latest advertised release, and decides
/// whether an update is available.
///
/// The two reads are independent: a failure to reach the manifest is reported
/// as a [Result] error (so the UI can show it) while the installed version is
/// still returned when available.
class CheckForUpdate {
  const CheckForUpdate(this._versions, this._releases);

  final AppVersionSource _versions;
  final ReleaseSource _releases;

  Future<Result<UpdateCheck>> call() async {
    final AppVersion installed;
    try {
      installed = await _versions.current();
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(
        UnknownException('Could not read the installed version', cause: error),
      );
    }

    final AppRelease? latest;
    try {
      latest = await _releases.fetchLatest();
    } on AppException catch (error) {
      return Err(error);
    } catch (error) {
      return Err(UnknownException('Could not check for updates', cause: error));
    }

    return Ok(UpdateCheck(installed: installed, latest: latest));
  }
}
