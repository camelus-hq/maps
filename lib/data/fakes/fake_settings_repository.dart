import '../../domain/entities/app_settings.dart';
import '../../domain/ports/settings_repository.dart';

/// In-memory [SettingsRepository] so keyless/test runs work without platform
/// plugins; `lib/app/di.dart` swaps in the prefs-backed one.
class FakeSettingsRepository implements SettingsRepository {
  AppSettings _settings = const AppSettings();

  /// Defaults to "onboarded" so widget/golden tests land straight on the map;
  /// the prefs-backed repo defaults to not-seen for a real first run.
  bool _onboarded = true;

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  Future<bool> onboardingSeen() async => _onboarded;

  @override
  Future<void> setOnboardingSeen(bool seen) async => _onboarded = seen;

  int? _skippedUpdateVersionCode;

  @override
  Future<int?> skippedUpdateVersionCode() async => _skippedUpdateVersionCode;

  @override
  Future<void> setSkippedUpdateVersionCode(int? versionCode) async =>
      _skippedUpdateVersionCode = versionCode;
}
