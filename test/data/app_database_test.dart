import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/data/local/database/metric_event_codec.dart';
import 'package:openmaps/domain/entities/metric_event.dart';
import 'package:openmaps/domain/ports/app_database.dart';

void main() {
  group('settings', () {
    test('typed values round-trip', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.writeString('s', 'hello');
      await db.writeBool('b', true);
      await db.writeInt('i', 7);
      await db.writeStringList('l', <String>['a', 'b']);

      expect(await db.readString('s'), 'hello');
      expect(await db.readBool('b'), isTrue);
      expect(await db.readInt('i'), 7);
      expect(await db.readStringList('l'), <String>['a', 'b']);
      expect(await db.readSettings(), hasLength(4));
    });

    test('a missing key reads back as null', () async {
      final AppDatabase db = InMemoryAppDatabase();
      expect(await db.readString('nope'), isNull);
      expect(await db.readBool('nope'), isNull);
      expect(await db.readStringList('nope'), isNull);
    });

    test('a value of the wrong JSON type is dropped, not thrown', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.writeSetting('x', '"not a bool"');
      expect(await db.readBool('x'), isNull);
      await db.writeSetting('y', 'not json at all');
      expect(await db.readString('y'), isNull);
      await db.writeSetting('z', '{"a":1}');
      expect(await db.readStringList('z'), isNull);
    });

    test('deleteSetting removes a key', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.writeString('a', 'x');
      await db.deleteSetting('a');
      expect(await db.readString('a'), isNull);
    });
  });

  group('metrics', () {
    test('recorded metrics read back newest-first', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.recordMetric(
        MetricEvent.create('a', recordedAt: DateTime.utc(2026, 1, 1)),
      );
      await db.recordMetric(
        MetricEvent.create('b', recordedAt: DateTime.utc(2026, 3, 1)),
      );
      await db.recordMetric(
        MetricEvent.create('c', recordedAt: DateTime.utc(2026, 2, 1)),
      );

      final List<MetricEvent> events = await db.readMetrics();
      expect(events.map((MetricEvent e) => e.name), <String>['b', 'c', 'a']);
      expect(await db.countMetrics(), 3);
    });

    test(
      'readMetrics filters by name and since, and honours the limit',
      () async {
        final AppDatabase db = InMemoryAppDatabase();
        for (int i = 0; i < 5; i++) {
          await db.recordMetric(
            MetricEvent.create(
              i.isEven ? 'even' : 'odd',
              recordedAt: DateTime.utc(2026, 1, i + 1),
            ),
          );
        }

        expect(await db.countMetrics(name: 'even'), 3);
        expect(await db.countMetrics(since: DateTime.utc(2026, 1, 4)), 2);
        final List<MetricEvent> limited = await db.readMetrics(limit: 2);
        expect(limited, hasLength(2));
        // Newest first.
        expect(limited.first.recordedAt, DateTime.utc(2026, 1, 5));
      },
    );

    test('deleteMetricsBefore removes only older rows', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.recordMetric(
        MetricEvent.create('old', recordedAt: DateTime.utc(2026, 1, 1)),
      );
      await db.recordMetric(
        MetricEvent.create('new', recordedAt: DateTime.utc(2026, 6, 1)),
      );

      expect(await db.deleteMetricsBefore(DateTime.utc(2026, 3, 1)), 1);
      expect(await db.countMetrics(), 1);
      expect((await db.readMetrics()).single.name, 'new');
    });

    test('clearMetrics empties the log', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.recordMetric(MetricEvent.create('a'));
      await db.clearMetrics();
      expect(await db.countMetrics(), 0);
    });

    test('label values survive a JSON round-trip', () async {
      final AppDatabase db = InMemoryAppDatabase();
      await db.recordMetric(
        MetricEvent.create('e', labels: <String, String>{'k': 'v', 'n': '2'}),
      );
      expect((await db.readMetrics()).single.labels, <String, String>{
        'k': 'v',
        'n': '2',
      });
    });
  });

  group('MetricEventCodec', () {
    test('encodes and decodes a label map', () {
      const Map<String, String> labels = <String, String>{'a': '1', 'b': '2'};
      final String encoded = MetricEventCodec.encodeLabels(labels);
      expect(MetricEventCodec.decodeLabels(encoded), labels);
    });

    test('hostile input decodes to an empty map', () {
      expect(MetricEventCodec.decodeLabels(null), isEmpty);
      expect(MetricEventCodec.decodeLabels(''), isEmpty);
      expect(MetricEventCodec.decodeLabels('not json'), isEmpty);
      expect(MetricEventCodec.decodeLabels('[1,2,3]'), isEmpty);
      expect(MetricEventCodec.decodeLabels('{"a": 1}'), isEmpty);
    });

    test('drops non-string entries and caps the count', () {
      final Map<String, String> mixed = MetricEventCodec.decodeLabels(
        '{"ok":"yes","bad":5,"also":"fine"}',
      );
      expect(mixed, <String, String>{'ok': 'yes', 'also': 'fine'});

      final String tooMany = MetricEventCodec.encodeLabels(<String, String>{
        for (int i = 0; i < MetricEvent.maxLabels + 10; i++) 'k$i': 'v',
      });
      expect(
        MetricEventCodec.decodeLabels(tooMany),
        hasLength(MetricEvent.maxLabels),
      );
    });
  });
}
