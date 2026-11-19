import '../../../domain/ports/app_database.dart';
import 'objectbox/objectbox_app_database.dart';

/// Opens the native (ObjectBox) database. See `app_database_factory.dart`.
Future<AppDatabase> openAppDatabase({
  String? directory,
  bool attach = false,
}) async {
  final ObjectBoxAppDatabase database = ObjectBoxAppDatabase(
    directory: directory,
    attach: attach,
  );
  await database.open();
  return database;
}
