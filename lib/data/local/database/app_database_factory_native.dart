import '../../../domain/ports/app_database.dart';
import 'objectbox/objectbox_app_database.dart';

/// Opens the native (ObjectBox) database. See `app_database_factory.dart`.
Future<AppDatabase> openAppDatabase({String? directory}) async {
  final ObjectBoxAppDatabase database = ObjectBoxAppDatabase(
    directory: directory,
  );
  await database.open();
  return database;
}
