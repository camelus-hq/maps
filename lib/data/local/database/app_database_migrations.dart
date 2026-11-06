import '../../../domain/ports/app_database.dart';

/// The settings key holding the applied schema version. Reserved: it is
/// managed by [runAppDatabaseMigrations] and must not be written by features.
const String kAppDatabaseSchemaVersionKey = '_schema_version';

/// The current app-database schema version.
///
/// **Bump this whenever the stored shape changes** and add a matching entry to
/// [appDatabaseDataMigrations] (for data changes) and/or a structural step in
/// each adapter's own migration hook (for new tables/columns). `docs/database.md`
/// has the checklist.
const int kAppDatabaseSchemaVersion = 1;

/// One data migration: an ordered upgrade step that runs **after** the store is
/// open, using only the [AppDatabase] port so it behaves identically on every
/// backend.
class AppDatabaseMigration {
  const AppDatabaseMigration({
    required this.to,
    required this.description,
    required this.run,
  });

  /// The schema version this step produces. Steps run in ascending order and
  /// only those above the stored version run.
  final int to;

  /// A short, human-readable summary (for logs and tests).
  final String description;

  final Future<void> Function(AppDatabase db) run;
}

/// Backend-independent data migrations, in ascending version order.
///
/// Version 1 is the initial schema, so there is nothing to do yet. When the
/// shape changes, add e.g.:
///
/// ```dart
/// AppDatabaseMigration(
///   to: 2,
///   description: 'backfill metric labels',
///   run: (AppDatabase db) async { … },
/// ),
/// ```
///
/// Structural changes (a new table/box or column/property) are handled by the
/// adapters, because ObjectBox's model and drift's DDL differ: see
/// `objectbox/objectbox_app_database.dart` and `drift/drift_app_database.dart`.
const List<AppDatabaseMigration> appDatabaseDataMigrations =
    <AppDatabaseMigration>[];

/// Brings [db] up to [AppDatabase.schemaVersion], running every pending data
/// migration in order. Returns `true` when the stored version changed.
///
/// Hostile input is tolerated: a negative stored version is treated as `0`, and
/// a store that is *ahead* of this build (an older app on a newer store) is left
/// untouched rather than downgraded or wiped.
Future<bool> runAppDatabaseMigrations(
  AppDatabase db, {
  List<AppDatabaseMigration> migrations = appDatabaseDataMigrations,
}) async {
  final int raw = await db.readStoredSchemaVersion();
  final int stored = raw < 0 ? 0 : raw;
  final int target = db.schemaVersion;

  if (stored >= target) {
    return false;
  }

  for (final AppDatabaseMigration migration in migrations) {
    if (migration.to > stored && migration.to <= target) {
      await migration.run(db);
    }
  }

  await db.writeStoredSchemaVersion(target);
  return true;
}
