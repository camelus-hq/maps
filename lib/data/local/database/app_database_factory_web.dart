import 'package:drift/wasm.dart';

import '../../../domain/ports/app_database.dart';
import 'drift/drift_app_database.dart';

/// Opens the web (drift over WASM SQLite) database. See
/// `app_database_factory.dart`.
///
/// Requires `sqlite3.wasm` and `drift_worker.js` in `web/` (see
/// `docs/database.md`). [directory] is ignored — the browser storage location
/// is chosen by drift.
Future<AppDatabase> openAppDatabase({String? directory}) async {
  final WasmDatabaseResult result = await WasmDatabase.open(
    databaseName: 'openmaps',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  );
  final DriftAppDatabase database = DriftAppDatabase(result.resolvedExecutor);
  await database.open();
  return database;
}
