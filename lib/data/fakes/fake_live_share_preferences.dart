import '../../domain/entities/live_share.dart';
import '../../domain/ports/live_share_preferences.dart';

/// In-memory [LiveSharePreferences] for tests and keyless runs.
class FakeLiveSharePreferences implements LiveSharePreferences {
  LiveShareDefaults defaults = const LiveShareDefaults();

  int saves = 0;

  @override
  Future<LiveShareDefaults> load() async => defaults;

  @override
  Future<void> save(LiveShareDefaults defaults) async {
    this.defaults = defaults;
    saves++;
  }
}
