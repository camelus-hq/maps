import 'package:flutter/foundation.dart';

import '../data/fakes/in_memory_app_database.dart';
import '../data/local/database/app_database_factory.dart';
import '../domain/ports/app_database.dart';

/// Opens the platform local database, degrading to an in-memory store when it
/// cannot be opened (a corrupt store, a missing native library, a first-run
/// failure). A database problem must never stop the app from starting — see
/// AGENTS.md "Never crash" — so the failure is logged and the app keeps going
/// with a non-persistent store.
Future<AppDatabase> openAppDatabaseSafely() async {
  try {
    return await openAppDatabase();
  } catch (error) {
    debugPrint(
      'Local database unavailable, falling back to in-memory storage: $error',
    );
    return InMemoryAppDatabase();
  }
}
