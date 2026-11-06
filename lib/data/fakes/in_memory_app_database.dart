import '../../domain/entities/metric_event.dart';
import '../../domain/ports/app_database.dart';
import '../local/database/app_database_migrations.dart';

/// In-memory [AppDatabase] for tests and keyless runs (no platform plugins).
///
/// It mirrors the real adapters' observable behaviour — newest-first metrics,
/// filtering, limiting, JSON settings, the schema-version bookkeeping — so a
/// test that passes against this passes against ObjectBox/drift too. It also
/// backs the bootstrap fallback when the platform store cannot be opened.
class InMemoryAppDatabase implements AppDatabase {
  InMemoryAppDatabase([this._schemaVersion = kAppDatabaseSchemaVersion]);

  final int _schemaVersion;
  final Map<String, String> _settings = <String, String>{};
  final List<MetricEvent> _metrics = <MetricEvent>[];
  int _storedSchemaVersion = 0;
  int _nextId = 1;
  bool _open = false;

  @override
  int get schemaVersion => _schemaVersion;

  @override
  bool get isOpen => _open;

  @override
  Future<void> open() async {
    if (_open) {
      return;
    }
    _open = true;
    await runAppDatabaseMigrations(this);
  }

  @override
  Future<void> close() async => _open = false;

  @override
  Future<String?> readSetting(String key) async => _settings[key];

  @override
  Future<void> writeSetting(String key, String json) async =>
      _settings[key] = json;

  @override
  Future<void> deleteSetting(String key) async => _settings.remove(key);

  @override
  Future<Map<String, String>> readSettings() async =>
      Map<String, String>.unmodifiable(_settings);

  @override
  Future<int> recordMetric(MetricEvent event) async {
    final int id = _nextId++;
    _metrics.add(
      MetricEvent(
        id: id,
        name: event.name,
        recordedAt: event.recordedAt,
        value: event.value,
        labels: event.labels,
      ),
    );
    return id;
  }

  @override
  Future<List<MetricEvent>> readMetrics({
    String? name,
    DateTime? since,
    int limit = 200,
  }) async {
    final List<MetricEvent> matching =
        _metrics.where((MetricEvent event) {
          if (name != null && event.name != name) {
            return false;
          }
          if (since != null && event.recordedAt.isBefore(since)) {
            return false;
          }
          return true;
        }).toList()..sort(
          (MetricEvent a, MetricEvent b) =>
              b.recordedAt.compareTo(a.recordedAt),
        );
    if (limit > 0 && matching.length > limit) {
      return matching.sublist(0, limit);
    }
    return matching;
  }

  @override
  Future<int> countMetrics({String? name, DateTime? since}) async {
    return _metrics.where((MetricEvent event) {
      if (name != null && event.name != name) {
        return false;
      }
      if (since != null && event.recordedAt.isBefore(since)) {
        return false;
      }
      return true;
    }).length;
  }

  @override
  Future<int> deleteMetricsBefore(DateTime cutoff) async {
    final int before = _metrics.length;
    _metrics.removeWhere(
      (MetricEvent event) => event.recordedAt.isBefore(cutoff),
    );
    return before - _metrics.length;
  }

  @override
  Future<void> clearMetrics() async => _metrics.clear();

  @override
  Future<int> readStoredSchemaVersion() async => _storedSchemaVersion;

  @override
  Future<void> writeStoredSchemaVersion(int version) async =>
      _storedSchemaVersion = version;
}
