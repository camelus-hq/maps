import '../entities/metric_event.dart';

/// The app's local database.
///
/// A deliberately small, package-free contract: a key/value settings store plus
/// an append-only metric log. It is implemented per platform — ObjectBox on
/// native, drift over SQLite/WASM on the web — and chosen by a conditional
/// import in `lib/data/local/database/app_database_factory.dart`, so this port
/// and its callers stay free of Flutter and database packages.
///
/// Settings values cross this boundary as **raw, JSON-encoded strings** (use
/// the typed helpers in `lib/data/local/database/app_database_values.dart`), so
/// both backends store byte-for-byte the same thing.
///
/// **Never crash:** no method here may throw for expected conditions — a
/// missing key returns `null`, an unreadable value is dropped, and callers
/// surface failures as typed errors instead of letting the UI die. A store that
/// cannot be opened is caught at bootstrap and replaced by an in-memory one.
abstract interface class AppDatabase {
  /// The schema version this build expects. See `docs/database.md`.
  int get schemaVersion;

  /// Whether [open] has completed and [close] has not run since.
  bool get isOpen;

  /// Opens the store and brings its schema up to date, running migrations.
  ///
  /// Idempotent: calling it on an already-open database does nothing.
  Future<void> open();

  /// Flushes and releases the store. Safe to call when already closed.
  Future<void> close();

  // ---------------------------------------------------------------------------
  // Settings (raw JSON values)
  // ---------------------------------------------------------------------------

  /// The raw JSON value stored under [key], or `null`.
  Future<String?> readSetting(String key);

  /// Stores [json] under [key], replacing any previous value.
  Future<void> writeSetting(String key, String json);

  /// Removes [key] if present.
  Future<void> deleteSetting(String key);

  /// Every stored setting, keyed by setting name. Internal bookkeeping keys
  /// (see [readStoredSchemaVersion]) are included; callers may filter them.
  Future<Map<String, String>> readSettings();

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  /// Appends [event] and returns its assigned id.
  Future<int> recordMetric(MetricEvent event);

  /// Metrics ordered newest first, optionally filtered by [name] and [since],
  /// capped at [limit] rows.
  Future<List<MetricEvent>> readMetrics({
    String? name,
    DateTime? since,
    int limit = 200,
  });

  /// The number of stored metrics (matching [name] and [since] when given).
  Future<int> countMetrics({String? name, DateTime? since});

  /// Deletes metrics recorded strictly before [cutoff]; returns how many went.
  Future<int> deleteMetricsBefore(DateTime cutoff);

  /// Deletes every metric.
  Future<void> clearMetrics();

  // ---------------------------------------------------------------------------
  // Schema bookkeeping (used by the migration runner)
  // ---------------------------------------------------------------------------

  /// The schema version last applied by the migration runner, or `0` for a
  /// store that has never been migrated.
  Future<int> readStoredSchemaVersion();

  /// Records [version] as the applied schema version.
  Future<void> writeStoredSchemaVersion(int version);
}
