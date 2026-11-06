import 'package:drift/drift.dart';

import '../../../../domain/entities/metric_event.dart';
import '../../../../domain/ports/app_database.dart';
import '../app_database_migrations.dart';
import '../metric_event_codec.dart';
import 'drift_tables.dart';

part 'drift_app_database.g.dart';

/// [AppDatabase] for the web, backed by drift over a WebAssembly SQLite
/// database.
///
/// The [QueryExecutor] is injected, so the same class runs against a WASM
/// executor in the app and an in-memory SQLite executor in tests. Structural
/// upgrades (new tables/columns) belong in [migration]'s `onUpgrade`; data
/// transforms live once, backend independently, in
/// `../app_database_migrations.dart` and run in `beforeOpen`.
@DriftDatabase(tables: <Type>[DbSettings, DbMetrics])
class DriftAppDatabase extends _$DriftAppDatabase implements AppDatabase {
  DriftAppDatabase(super.executor);

  bool _opened = false;

  @override
  int get schemaVersion => kAppDatabaseSchemaVersion;

  @override
  bool get isOpen => _opened;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Add structural steps here as the schema grows, e.g.:
      //   if (from < 2) {
      //     await m.createTable(dbMetrics);
      //   }
      // Keep them guarded by the *from* version so an old store is walked
      // forward one step at a time.
    },
    beforeOpen: (OpeningDetails details) async {
      await runAppDatabaseMigrations(this);
    },
  );

  @override
  Future<void> open() async {
    if (_opened) {
      return;
    }
    // Touching the database opens the connection, which runs `onCreate` /
    // `onUpgrade` and then `beforeOpen` (and therefore the migrations).
    await customSelect('SELECT 1').get();
    _opened = true;
  }

  @override
  Future<void> close() async {
    _opened = false;
    await super.close();
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  @override
  Future<String?> readSetting(String key) async {
    final DbSetting? row = await (select(
      dbSettings,
    )..where((DbSettings t) => t.key.equals(key))).getSingleOrNull();
    return row?.json;
  }

  @override
  Future<void> writeSetting(String key, String json) => into(dbSettings)
      .insertOnConflictUpdate(DbSettingsCompanion.insert(key: key, json: json));

  @override
  Future<void> deleteSetting(String key) =>
      (delete(dbSettings)..where((DbSettings t) => t.key.equals(key))).go();

  @override
  Future<Map<String, String>> readSettings() async {
    final List<DbSetting> rows = await select(dbSettings).get();
    return Map<String, String>.unmodifiable(<String, String>{
      for (final DbSetting row in rows) row.key: row.json,
    });
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  @override
  Future<int> recordMetric(MetricEvent event) => into(dbMetrics).insert(
    DbMetricsCompanion.insert(
      name: event.name,
      recordedAt: event.recordedAt.millisecondsSinceEpoch,
      value: Value<double?>(event.value),
      labels: Value<String>(MetricEventCodec.encodeLabels(event.labels)),
    ),
  );

  @override
  Future<List<MetricEvent>> readMetrics({
    String? name,
    DateTime? since,
    int limit = 200,
  }) async {
    final SimpleSelectStatement<DbMetrics, DbMetric> query = _metricsSelect(
      name,
      since,
    );
    query.orderBy(<OrderClauseGenerator<DbMetrics>>[
      (DbMetrics t) => OrderingTerm.desc(t.recordedAt),
    ]);
    if (limit > 0) {
      query.limit(limit);
    }
    final List<DbMetric> rows = await query.get();
    return rows.map(_toEvent).toList(growable: false);
  }

  @override
  Future<int> countMetrics({String? name, DateTime? since}) async {
    final Expression<int> count = dbMetrics.id.count();
    final JoinedSelectStatement<DbMetrics, DbMetric> query = selectOnly(
      dbMetrics,
    )..addColumns(<Expression<Object>>[count]);
    if (name != null) {
      query.where(dbMetrics.name.equals(name));
    }
    if (since != null) {
      query.where(
        dbMetrics.recordedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
      );
    }
    final TypedResult row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  @override
  Future<int> deleteMetricsBefore(DateTime cutoff) =>
      (delete(dbMetrics)..where(
            (DbMetrics t) =>
                t.recordedAt.isSmallerThanValue(cutoff.millisecondsSinceEpoch),
          ))
          .go();

  @override
  Future<void> clearMetrics() => delete(dbMetrics).go();

  SimpleSelectStatement<DbMetrics, DbMetric> _metricsSelect(
    String? name,
    DateTime? since,
  ) {
    final SimpleSelectStatement<DbMetrics, DbMetric> query = select(dbMetrics);
    if (name != null) {
      query.where((DbMetrics t) => t.name.equals(name));
    }
    if (since != null) {
      query.where(
        (DbMetrics t) =>
            t.recordedAt.isBiggerOrEqualValue(since.millisecondsSinceEpoch),
      );
    }
    return query;
  }

  // ---------------------------------------------------------------------------
  // Schema bookkeeping
  // ---------------------------------------------------------------------------

  @override
  Future<int> readStoredSchemaVersion() async {
    final String? raw = await readSetting(kAppDatabaseSchemaVersionKey);
    if (raw == null) {
      return 0;
    }
    return int.tryParse(raw) ?? 0;
  }

  @override
  Future<void> writeStoredSchemaVersion(int version) =>
      writeSetting(kAppDatabaseSchemaVersionKey, '$version');

  MetricEvent _toEvent(DbMetric row) => MetricEvent(
    id: row.id,
    name: row.name,
    recordedAt: DateTime.fromMillisecondsSinceEpoch(
      row.recordedAt,
      isUtc: true,
    ),
    value: row.value,
    labels: MetricEventCodec.decodeLabels(row.labels),
  );
}
