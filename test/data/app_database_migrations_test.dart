import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/in_memory_app_database.dart';
import 'package:openmaps/data/local/database/app_database_migrations.dart';
import 'package:openmaps/data/local/database/app_database_values.dart';
import 'package:openmaps/domain/ports/app_database.dart';

void main() {
  AppDatabaseMigration step(int to, List<int> ran) => AppDatabaseMigration(
    to: to,
    description: 'step $to',
    run: (AppDatabase db) async {
      ran.add(to);
      await db.writeBool('ran.$to', true);
    },
  );

  test('a fresh store is stamped with the current schema version', () async {
    final AppDatabase db = InMemoryAppDatabase();
    expect(await db.readStoredSchemaVersion(), 0);

    final bool changed = await runAppDatabaseMigrations(db);

    expect(changed, isTrue);
    expect(await db.readStoredSchemaVersion(), kAppDatabaseSchemaVersion);
  });

  test('re-running migrations when already current is a no-op', () async {
    final AppDatabase db = InMemoryAppDatabase();
    await runAppDatabaseMigrations(db);

    expect(await runAppDatabaseMigrations(db), isFalse);
  });

  test('pending steps run in ascending order', () async {
    final AppDatabase db = InMemoryAppDatabase(3);
    final List<int> ran = <int>[];

    final bool changed = await runAppDatabaseMigrations(
      db,
      migrations: <AppDatabaseMigration>[step(2, ran), step(3, ran)],
    );

    expect(changed, isTrue);
    expect(ran, <int>[2, 3]);
    expect(await db.readStoredSchemaVersion(), 3);
    expect(await db.readBool('ran.2'), isTrue);
    expect(await db.readBool('ran.3'), isTrue);
  });

  test('a store already partway only runs the newer steps', () async {
    final AppDatabase db = InMemoryAppDatabase(3);
    await db.writeStoredSchemaVersion(2);
    final List<int> ran = <int>[];

    await runAppDatabaseMigrations(
      db,
      migrations: <AppDatabaseMigration>[step(2, ran), step(3, ran)],
    );

    expect(ran, <int>[3]);
    expect(await db.readStoredSchemaVersion(), 3);
  });

  test('a store ahead of the build is left untouched', () async {
    final AppDatabase db = InMemoryAppDatabase(1);
    await db.writeStoredSchemaVersion(9);
    final List<int> ran = <int>[];

    final bool changed = await runAppDatabaseMigrations(
      db,
      migrations: <AppDatabaseMigration>[step(2, ran)],
    );

    expect(changed, isFalse);
    expect(ran, isEmpty);
    expect(await db.readStoredSchemaVersion(), 9);
  });

  test('a hostile (negative) stored version is treated as 0', () async {
    final AppDatabase db = InMemoryAppDatabase(2);
    await db.writeStoredSchemaVersion(-5);
    final List<int> ran = <int>[];

    await runAppDatabaseMigrations(
      db,
      migrations: <AppDatabaseMigration>[step(2, ran)],
    );

    expect(ran, <int>[2]);
    expect(await db.readStoredSchemaVersion(), 2);
  });
}
