import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/local/database/app_database_migrations.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/data/local/database/drift/drift_app_database.dart';
import 'package:openmaps/domain/entities/metric_event.dart';

void main() {
  late DriftAppDatabase db;

  setUp(() => db = DriftAppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('opens, stamps the schema version and records it once', () async {
    await db.open();
    expect(db.isOpen, isTrue);
    expect(await db.readStoredSchemaVersion(), kAppDatabaseSchemaVersion);

    // Opening again is idempotent and does not re-run migrations.
    await db.open();
    expect(db.isOpen, isTrue);
  });

  test('settings round-trip through the typed helpers', () async {
    await db.open();
    await db.writeString('settings.unit', 'imperial');
    await db.writeBool('settings.flag', true);
    await db.writeInt('settings.count', 3);
    await db.writeStringList('settings.list', <String>['a', 'b']);

    expect(await db.readString('settings.unit'), 'imperial');
    expect(await db.readBool('settings.flag'), isTrue);
    expect(await db.readInt('settings.count'), 3);
    expect(await db.readStringList('settings.list'), <String>['a', 'b']);

    await db.deleteSetting('settings.unit');
    expect(await db.readString('settings.unit'), isNull);
  });

  test('metrics round-trip, filter and delete', () async {
    await db.open();
    final int id = await db.recordMetric(
      MetricEvent.create(
        'app.open',
        recordedAt: DateTime.utc(2026, 1, 1),
        value: 1.5,
        labels: <String, String>{'k': 'v'},
      ),
    );
    expect(id, greaterThan(0));

    await db.recordMetric(
      MetricEvent.create('app.open', recordedAt: DateTime.utc(2026, 2, 1)),
    );

    final List<MetricEvent> events = await db.readMetrics(name: 'app.open');
    expect(events, hasLength(2));
    // Newest first.
    expect(events.first.recordedAt, DateTime.utc(2026, 2, 1));
    expect(events.last.value, 1.5);
    expect(events.last.labels, <String, String>{'k': 'v'});

    expect(await db.countMetrics(), 2);
    expect(await db.countMetrics(name: 'app.open'), 2);
    expect(await db.countMetrics(since: DateTime.utc(2026, 1, 15)), 1);
    expect(await db.readMetrics(limit: 1), hasLength(1));

    expect(await db.deleteMetricsBefore(DateTime.utc(2026, 1, 15)), 1);
    expect(await db.countMetrics(), 1);
    await db.clearMetrics();
    expect(await db.countMetrics(), 0);
  });
}
