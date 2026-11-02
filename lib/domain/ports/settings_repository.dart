import '../entities/app_settings.dart';

/// Persists the user's [AppSettings] (local only — no account, no cloud).
abstract interface class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);

  /// Whether the first-run onboarding has been completed.
  Future<bool> onboardingSeen();
  Future<void> setOnboardingSeen(bool seen);

  /// The `versionCode` of the last update the user declined (the prompt is not
  /// shown again for it), or `null` when none was declined.
  Future<int?> skippedUpdateVersionCode();
  Future<void> setSkippedUpdateVersionCode(int? versionCode);
}
