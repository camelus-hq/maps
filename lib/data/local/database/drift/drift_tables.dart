import 'package:drift/drift.dart';

/// A settings key/value pair. The value is JSON so one column serves strings,
/// booleans, numbers and string lists.
class DbSettings extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// One recorded metric event.
class DbMetrics extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get recordedAt => integer()();
  RealColumn get value => real().nullable()();
  TextColumn get labels => text().withDefault(const Constant<String>('{}'))();
}
