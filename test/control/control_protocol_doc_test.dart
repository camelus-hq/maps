import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/state/commands/commands_provider.dart';

/// Keeps `docs/control-protocol.md`'s generated command index in sync with the
/// live registry (M9.4): the registry is the single source of truth, so the doc
/// must never drift.
///
/// Regenerate after adding/renaming a command:
///   `UPDATE_PROTOCOL_DOC=1 flutter test test/control/control_protocol_doc_test.dart`
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String begin = '<!-- BEGIN GENERATED COMMANDS -->';
  const String end = '<!-- END GENERATED COMMANDS -->';

  test('control-protocol.md index matches the command registry', () async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Object?> list =
        await container
                .read(commandRegistryProvider)
                .dispatch('session.list', const <String, Object?>{})
            as List<Object?>;
    final List<Map<String, Object?>> rows =
        list.map((Object? entry) => entry as Map<String, Object?>).toList()
          ..sort(
            (Map<String, Object?> a, Map<String, Object?> b) =>
                (a['id']! as String).compareTo(b['id']! as String),
          );

    final StringBuffer block = StringBuffer()
      ..writeln(begin)
      ..writeln('| id | description |')
      ..writeln('|---|---|');
    for (final Map<String, Object?> row in rows) {
      final String description = (row['description'] ?? '')
          .toString()
          .replaceAll('|', r'\|');
      block
        ..writeln('| `${row['id']}` | $description |')
        ..write('');
    }
    block.write(end);

    final File file = File('docs/control-protocol.md');
    final String content = file.readAsStringSync();
    final int start = content.indexOf(begin);
    expect(
      start,
      greaterThanOrEqualTo(0),
      reason: 'the doc needs a generated index block',
    );
    final int stop = content.indexOf(end, start);
    expect(stop, greaterThan(start));

    if (Platform.environment['UPDATE_PROTOCOL_DOC'] == '1') {
      final String updated =
          '${content.substring(0, start)}${block.toString()}'
          '${content.substring(stop + end.length)}';
      file.writeAsStringSync(updated);
      return;
    }

    final String existing = content.substring(start, stop + end.length);
    expect(
      existing.trimRight(),
      block.toString().trimRight(),
      reason: 'run UPDATE_PROTOCOL_DOC=1 to regenerate the command index',
    );
  });
}
