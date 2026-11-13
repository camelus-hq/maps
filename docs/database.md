# Local app database

OpenMaps keeps its on-device data — recorded metrics and the settings that are
not needed before the first frame — in one local database, behind the
[`AppDatabase`](../lib/domain/ports/app_database.dart) port. It is **local
only**: nothing here is uploaded, and no server is contacted.

The implementation is chosen per platform by a conditional import, so each
build compiles exactly one backend and its dependencies:

| Platform | Backend | Binding / engine |
|---|---|---|
| Native (Android, iOS, desktop) | [ObjectBox](https://pub.dev/packages/objectbox) | `objectbox` + `objectbox_flutter_libs` (fast embedded NoSQL, Dart objects) |
| Web | [drift](https://pub.dev/packages/drift) | SQLite compiled to WebAssembly (`web/sqlite3.wasm` + `web/drift_worker.js`) |

```
lib/domain/ports/app_database.dart            the contract (pure Dart)
lib/data/local/database/
  app_database_factory.dart                   conditional import → native | web
  app_database_factory_native.dart            ObjectBox
  app_database_factory_web.dart               drift over WASM SQLite
  app_database_migrations.dart                version + shared data migrations
  app_database_values.dart                    typed helpers over raw JSON values
  metric_event_codec.dart                     label map <-> JSON (both backends)
  objectbox/                                  native backend + generated binding
  drift/                                      web backend + generated binding
lib/data/fakes/in_memory_app_database.dart    tests / keyless runs / open fallback
```

`AppDatabase` is small on purpose: a key/value settings store (values are raw
JSON, so one column serves strings, booleans, numbers and string lists) plus an
append-only metric log (`MetricEvent`). Both backends store byte-for-byte the
same thing, and the shared tests run against the in-memory and drift stores, so
the ObjectBox path only differs in its storage engine.

## Opening it

`openAppDatabaseSafely()` (in `lib/app/database_bootstrap.dart`) is awaited in
`main()` before the first frame, so migrations run once at startup. A store that
cannot be opened (corrupt file, a missing native library, a first-run failure)
is caught, logged, and replaced by an in-memory store — a database problem never
stops the app from starting. The result is provided through
`appDatabaseProvider` (default: in-memory) and wired into `lib/app/di.dart`.

`AppSettings` (unit, developer options, search provider, pinned chips) lives in
the database; the **theme**, the **onboarding flag** and the **skipped-update
version** stay in `shared_preferences` because they are read before the database
is needed. `LocalSettingsRepository` reads the first set from the database and
the second from prefs, and copies any pre-database (`shared_preferences`) values
into the database once.

The **places** store (`DatabasePlacesRepository`) also lives in the database:
the recent searches (opened/navigated-to places and submitted queries), the saved
**Home**/**Work** places and the bookmarks are JSON values under the `places.*`
keys, so a new entry needs no schema change. It copies the pre-database
`openmaps.recent_queries` / `openmaps.bookmarks` values in once, the same way the
settings do.

The **persistent anonymous Nostr identity** (see
[`docs/nostr-nips.md`](nostr-nips.md)) is a JSON value under the
`identity.anonymous` key: a key pair generated once on first use and reused, so
feedback — and any future anonymous feature — keeps one stable key without a
schema change. It is local-only and its private key never leaves the device
except as the NIP-17 encrypted payload.

## Migrations — the checklist

Everything hinges on one integer, `kAppDatabaseSchemaVersion` in
`app_database_migrations.dart`. Bump it for **any** stored-shape change, then:

1. **Data change** (backfill, rename a value, split a field): add an
   `AppDatabaseMigration` to `appDatabaseDataMigrations` with `to: <new
   version>`. It runs against the `AppDatabase` port, so it is backend
   independent and is covered by `test/data/app_database_migrations_test.dart`.
2. **Structural change (native / ObjectBox):** add/remove properties on the
   `@Entity` classes in `objectbox/objectbox_entities.dart` and re-run the
   generator. ObjectBox keeps stable UIDs in `objectbox-model.json`, so adding
   removing and renaming-safe properties needs no migration code — **but commit
   `objectbox-model.json`**, it is the schema bookkeeping.
3. **Structural change (web / drift):** add the table/column to
   `drift/drift_tables.dart` and add a guarded step to `DriftAppDatabase`'s
   `onUpgrade` (e.g. `if (from < 2) { await m.createTable(dbMetrics); }`). The
   drift `schemaVersion` is `kAppDatabaseSchemaVersion`.

The migration runner is hostile-safe: a negative stored version is treated as
`0`, an already-current store is a no-op, and a store that is *ahead* of the
running build (an older app on a newer store) is left untouched rather than
downgraded or wiped.

## Code generation

Both backends generate bindings with `build_runner`:

```sh
dart run build_runner build
```

This writes `lib/data/local/database/objectbox/objectbox.g.dart` and
`objectbox-model.json`, and `lib/data/local/database/drift/drift_app_database.g.dart`.
**Commit all of them** — `objectbox-model.json` especially. Generated files are
excluded from the lints in `analysis_options.yaml`.

`objectbox_generator` and `drift_dev` currently require disjoint `analyzer`
ranges, and `objectbox_generator` needs `build ^4`, so `pubspec.yaml` pins
`drift_dev` below `2.34.1` (analyzer) and `build_runner` below `2.17`. The
`drift` **runtime** is kept on the newest 2.34.x (`>=2.34.3 <2.35.0`) so the web
worker + wasm pair it ships is a matched set. Raise these caps together once the
generators agree, then re-run the generator and re-download both web assets.

## Web assets

`web/sqlite3.wasm` and `web/drift_worker.js` **must be downloaded from the same
drift release** — the one matching the `drift` version in `pubspec.lock`. Since
drift 2.34.2 that release attaches both files, so this is a single download:

```sh
DRIFT_TAG=drift-2.34.4   # = the resolved `drift` version
curl -fL -o web/drift_worker.js \
  https://github.com/simolus3/drift/releases/download/$DRIFT_TAG/drift_worker.js
curl -fL -o web/sqlite3.wasm \
  https://github.com/simolus3/drift/releases/download/$DRIFT_TAG/sqlite3.wasm
```

Do **not** take the wasm from a newer `sqlite3.dart` release than the worker:
drift's worker only supports newer `sqlite3` packages, not newer wasm modules.
Mismatching them fails at WebAssembly instantiation on the web
(`LinkError: … Import "dart" "xFileControl": function import requires a
callable`) — and, because that error only appears when the wasm is loaded inside
the worker, it can show up in a debug run while a differently-served production
build happens to work. If you bump `drift`, re-download **both** files.

The server must send `Content-Type: application/wasm` for `sqlite3.wasm`
(`flutter run`/`flutter build web` do this by default).

## Testing

- `test/data/app_database_test.dart` — the port's behaviour on the in-memory
  store, plus the hostile label codec.
- `test/data/app_database_migrations_test.dart` — the migration runner
  (ordering, idempotence, downgrade and hostile-version handling).
- `test/data/drift_app_database_test.dart` — the drift adapter against an
  in-memory SQLite database (runs on the host).
- `test/data/objectbox_app_database_test.dart` — the ObjectBox adapter. Hosts
  without a matching ObjectBox native library skip the store test with a clear
  reason; download the library for your platform from the
  [ObjectBox C releases](https://github.com/objectbox/objectbox-c/releases) into
  `lib/` (e.g. `lib/libobjectbox.so`; git-ignored) to run it locally.
- `test/data/local_settings_repository_test.dart` — the settings split between
  the database and `shared_preferences`, including the legacy migration.
