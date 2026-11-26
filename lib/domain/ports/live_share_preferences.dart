import '../entities/live_share.dart';

/// Remembers the last live-location share's choices (who, and for how long) so
/// the share sheet can pre-select them the next time it opens.
///
/// Backed by the local app database; the fake is used in tests. Nothing here is
/// secret — only the recipients' public keys and the chosen duration.
abstract interface class LiveSharePreferences {
  /// The last-used choices, or an [LiveShareDefaults.isEmpty] value when
  /// nothing was stored (or every stored value was dropped as invalid).
  Future<LiveShareDefaults> load();

  /// Stores [defaults], replacing any previous value.
  Future<void> save(LiveShareDefaults defaults);
}
