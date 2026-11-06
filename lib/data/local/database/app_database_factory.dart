import '../../../domain/ports/app_database.dart';
import 'app_database_factory_native.dart'
    if (dart.library.js_interop) 'app_database_factory_web.dart'
    as platform;

/// Opens the local database for the current platform.
///
/// The conditional import compiles **ObjectBox** on native (Android, iOS,
/// desktop) and **drift over WASM SQLite** on the web, so only the matching
/// backend — and its native/JS dependencies — is pulled into a build. Both sit
/// behind the same [AppDatabase] port.
///
/// [directory] is honoured on native (tests point at an in-memory store) and
/// ignored on the web.
Future<AppDatabase> openAppDatabase({String? directory}) =>
    platform.openAppDatabase(directory: directory);
