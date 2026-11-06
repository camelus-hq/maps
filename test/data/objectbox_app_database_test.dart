import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/local/database/app_database_migrations.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/data/local/database/objectbox/objectbox_app_database.dart';
import 'package:openmaps/domain/entities/metric_event.dart';

void main() {
  test('reports the current schema version before it is opened', () {
    final ObjectBoxAppDatabase db = ObjectBoxAppDatabase(
      directory: 'memory:openmaps-contract',
    );
    expect(db.isOpen, isFalse);
    expect(db.schemaVersion, kAppDatabaseSchemaVersion);
  });

  test('throws an explicit StateError when used before open()', () async {
    final ObjectBoxAppDatabase db = ObjectBoxAppDatabase(
      directory: 'memory:openmaps-contract',
    );
    await expectLater(db.readSettings(), throwsA(isA<StateError>()));
  });

  test('round-trips settings, metrics and the schema version', () async {
    // The host test runner has no ObjectBox native library (it ships with the
    // Flutter app via `objectbox_flutter_libs`). The store behaviour is covered
    // on-device and by the identical drift adapter tests; here we run only when
    // the library can be loaded, and skip with a clear reason otherwise.
    final ObjectBoxAppDatabase db = ObjectBoxAppDatabase(
      directory: 'memory:openmaps-test',
    );
    try {
      await db.open();
    } on ArgumentError catch (error) {
      markTestSkipped(
        'ObjectBox native library unavailable on this host: $error',
      );
      return;
    } on UnsupportedError catch (error) {
      markTestSkipped(
        'ObjectBox native library is incompatible on this host: $error',
      );
      return;
    }
    addTearDown(db.close);

    expect(db.isOpen, isTrue);
    expect(await db.readStoredSchemaVersion(), kAppDatabaseSchemaVersion);

    await db.writeString('settings.unit', 'imperial');
    expect(await db.readString('settings.unit'), 'imperial');

    // Overwriting a key must replace, not duplicate.
    await db.writeString('settings.unit', 'metric');
    expect(await db.readString('settings.unit'), 'metric');
    final Map<String, String> settings = await db.readSettings();
    expect(settings['settings.unit'], '"metric"');
    expect(settings[kAppDatabaseSchemaVersionKey], '1');

    await db.recordMetric(
      MetricEvent.create(
        'app.open',
        value: 1.5,
        labels: <String, String>{'k': 'v'},
      ),
    );
    final List<MetricEvent> events = await db.readMetrics();
    expect(events.single.name, 'app.open');
    expect(events.single.value, 1.5);
    expect(events.single.labels, <String, String>{'k': 'v'});
    expect(await db.countMetrics(), 1);

    expect(await db.deleteMetricsBefore(DateTime.utc(2100)), 1);
    expect(await db.countMetrics(), 0);
  });
}
