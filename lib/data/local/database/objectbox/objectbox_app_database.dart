import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../domain/entities/metric_event.dart';
import '../../../../domain/ports/app_database.dart';
import '../app_database_migrations.dart';
import '../metric_event_codec.dart';
import 'objectbox.g.dart';
import 'objectbox_entities.dart';

/// [AppDatabase] for native platforms, backed by ObjectBox.
///
/// ObjectBox's model tracks added/removed properties automatically (stable UIDs
/// live in `objectbox-model.json`), so structural upgrades need no code here.
/// Anything that must *transform* existing data is expressed once, backend
/// independently, in `../app_database_migrations.dart` and run after open.
///
/// Pass [directory] to point at a specific store path; `memory:…` opens a
/// file-less in-memory store (used by tests).
class ObjectBoxAppDatabase implements AppDatabase {
  ObjectBoxAppDatabase({this.directory, this.storeName = 'openmaps-db'});

  /// Explicit store directory, or `null` to use the app documents directory.
  final String? directory;

  /// Subdirectory of the app documents directory when [directory] is `null`.
  final String storeName;

  Store? _store;

  Store get _openStore {
    final Store? store = _store;
    if (store == null) {
      throw StateError('ObjectBoxAppDatabase.open() must be called first');
    }
    return store;
  }

  Box<DbSettingEntity> get _settingsBox => _openStore.box<DbSettingEntity>();
  Box<DbMetricEntity> get _metricsBox => _openStore.box<DbMetricEntity>();

  @override
  int get schemaVersion => kAppDatabaseSchemaVersion;

  @override
  bool get isOpen => _store != null;

  @override
  Future<void> open() async {
    if (_store != null) {
      return;
    }
    final Store store = await openStore(directory: await _resolveDirectory());
    _store = store;
    await runAppDatabaseMigrations(this);
  }

  Future<String> _resolveDirectory() async {
    final String? explicit = directory;
    if (explicit != null) {
      return explicit;
    }
    final documents = await getApplicationDocumentsDirectory();
    return p.join(documents.path, storeName);
  }

  @override
  Future<void> close() async {
    _store?.close();
    _store = null;
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  @override
  Future<String?> readSetting(String key) async {
    for (final DbSettingEntity row in _settingsBox.getAll()) {
      if (row.key == key) {
        return row.json;
      }
    }
    return null;
  }

  @override
  Future<void> writeSetting(String key, String json) async {
    final Box<DbSettingEntity> box = _settingsBox;
    final Query<DbSettingEntity> query = box
        .query(DbSettingEntity_.key.equals(key))
        .build();
    try {
      final DbSettingEntity row =
          query.findFirst() ?? DbSettingEntity(key: key, json: json);
      row.json = json;
      box.put(row);
    } finally {
      query.close();
    }
  }

  @override
  Future<void> deleteSetting(String key) async {
    final Box<DbSettingEntity> box = _settingsBox;
    final Query<DbSettingEntity> query = box
        .query(DbSettingEntity_.key.equals(key))
        .build();
    try {
      final List<int> ids = query.findIds();
      if (ids.isNotEmpty) {
        box.removeMany(ids);
      }
    } finally {
      query.close();
    }
  }

  @override
  Future<Map<String, String>> readSettings() async {
    final Map<String, String> result = <String, String>{};
    for (final DbSettingEntity row in _settingsBox.getAll()) {
      result[row.key] = row.json;
    }
    return Map<String, String>.unmodifiable(result);
  }

  // ---------------------------------------------------------------------------
  // Metrics
  // ---------------------------------------------------------------------------

  @override
  Future<int> recordMetric(MetricEvent event) async =>
      _metricsBox.put(_toEntity(event));

  @override
  Future<List<MetricEvent>> readMetrics({
    String? name,
    DateTime? since,
    int limit = 200,
  }) async {
    final Box<DbMetricEntity> box = _metricsBox;
    final Query<DbMetricEntity> query = _metricsQuery(
      box,
      name,
      since,
    ).order(DbMetricEntity_.recordedAt, flags: Order.descending).build();
    try {
      if (limit > 0) {
        query.limit = limit;
      }
      return query.find().map(_toEvent).toList(growable: false);
    } finally {
      query.close();
    }
  }

  @override
  Future<int> countMetrics({String? name, DateTime? since}) async {
    final Query<DbMetricEntity> query = _metricsQuery(
      _metricsBox,
      name,
      since,
    ).build();
    try {
      return query.count();
    } finally {
      query.close();
    }
  }

  @override
  Future<int> deleteMetricsBefore(DateTime cutoff) async {
    final Box<DbMetricEntity> box = _metricsBox;
    final Query<DbMetricEntity> query = box
        .query(
          DbMetricEntity_.recordedAt.lessThan(cutoff.millisecondsSinceEpoch),
        )
        .build();
    try {
      final List<int> ids = query.findIds();
      return ids.isEmpty ? 0 : box.removeMany(ids);
    } finally {
      query.close();
    }
  }

  @override
  Future<void> clearMetrics() async {
    _metricsBox.removeAll();
  }

  QueryBuilder<DbMetricEntity> _metricsQuery(
    Box<DbMetricEntity> box,
    String? name,
    DateTime? since,
  ) {
    Condition<DbMetricEntity>? condition;
    if (name != null) {
      condition = DbMetricEntity_.name.equals(name);
    }
    if (since != null) {
      final Condition<DbMetricEntity> timeCondition = DbMetricEntity_.recordedAt
          .greaterOrEqual(since.millisecondsSinceEpoch);
      condition = condition == null ? timeCondition : condition & timeCondition;
    }
    return box.query(condition);
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

  DbMetricEntity _toEntity(MetricEvent event) => DbMetricEntity(
    name: event.name,
    recordedAt: event.recordedAt.millisecondsSinceEpoch,
    value: event.value,
    labels: MetricEventCodec.encodeLabels(event.labels),
  );

  MetricEvent _toEvent(DbMetricEntity row) => MetricEvent(
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
