import '../entities/live_share.dart';

/// Persists the active live-share session across app restarts.
///
/// Implemented over `shared_preferences`; the fake is used in tests.
abstract interface class LiveShareStore {
  /// The saved session, or `null` when nothing is being shared.
  Future<LiveShareSession?> load();

  /// Saves (or replaces) the active session.
  Future<void> save(LiveShareSession session);

  /// Removes the saved session.
  Future<void> clear();
}
