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
Future<AppDatabase> openAppDatabase({String? directory, bool attach = false}) =>
    platform.openAppDatabase(directory: directory, attach: attach);

/// Opens the local database **attached** to the store the UI isolate already
/// has open.
///
/// Used by the push background isolate: it runs in a separate Dart isolate while
/// the app is alive, so it cannot open a second store for the same directory.
/// `Store.attach` shares the existing native store instead. If the app is not
/// running (a push cold-start), it falls back to a normal open. See the
/// background handler in `lib/data/notifications/`.
Future<AppDatabase> openAppDatabaseAttached() => openAppDatabase(attach: true);
