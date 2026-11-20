# maps_api — OpenMaps push backend (Serverpod)

This workspace is a **backend only** Serverpod project. Its client is the
OpenMaps Flutter app at the repository root, which talks to it through the
generated `maps_api_client` package. There is no companion Flutter app here.

Its job is the **Nostr push forwarder** (see `docs/push.md`): it watches relays
for NIP-59 gift wraps addressed to registered identities and forwards them —
still encrypted — over FCM (default) or UnifiedPush, so neither the transport
provider nor a distributor can read the message. Registration is authenticated
by a BIP-340 **signed Nostr event**, not a Serverpod account. Serverpod's
built-in authentication (email/password + JWT) is set up in `lib/server.dart`
and stays available for future account features.

The server runs under the Serverpod runner, a background process per server
package. The user attaches to it with `serverpod start`. There is no need to
check if the server is running: make the changes and call the `serverpod` MCP
tools as needed. If the server is not running, an informative error message will
be received from the MCP server. Then call `tail_runner_logs` to learn whether it
is still starting or why it stopped. If nothing is running, start it with
`serverpod runner start` in `maps_api_server`, which returns once the server is
up and leaves it running for the user to attach to. If it fails, fix the cause it
reports (a build error, a port held by another process, Docker) instead of
retrying; only a `serverpod runner start` your shell killed on a timeout is run
again, since the runner keeps starting. Leave the runner running, and run
`serverpod runner stop` only when asked.

While running, the runner watches for file changes to run incremental code
generation and hot reload the server. `serverpod runner status` prints its state
and the server addresses, which are not always the configured ports when another
Serverpod runner on the machine holds them.

Calling `serverpod generate` directly is not needed, but might be useful to
troubleshoot when an incremental generation fails.

ALWAYS use the MCP server instead of the command line for the tasks below. The
`serverpod runner` commands are the exception: they manage the stack itself. Use
the MCP server to:

- `create_migration` and `apply_migrations` for database (after you change data models).
- `create_repair_migration` if the database has drifted out of sync with the migrations.
- `tail_server_logs` to read logs from the server.
- `tail_runner_logs` to read the output of the runner itself (code generation, compilation, Docker, raw server output). The only tool that also works while the server is starting or after it stopped.
- `hot_reload` / `hot_restart` to reload or restart the server.

NEVER edit generated code. The server's `lib/src/generated/` directory and the whole `maps_api_client` package are rewritten by the code generator. Change the `.spy.yaml` models, the endpoints, or `lib/server.dart` instead.

Migrations are a narrow exception: the `migration.sql` of a generated migration MAY be edited by hand when the generated SQL would lose data — to add a data transformation, or to reach a destructive change through non-destructive steps. Never touch the other files in the migration directory, and keep the schema the SQL ends up with identical to `definition.sql` — new databases are created from that file and never run `migration.sql`.

Only when the MCP is not available or `serverpod runner start` cannot bring the server up, fall back to the CLI in the server package:

- `serverpod generate` to regenerate the client and the generated server code.
- `serverpod create-migration` after changing a model with a `table` (add `--force` for destructive changes). It only writes the migration; the runner applies pending migrations when it boots the server.

Tests need no Docker. `config/test.yaml` sets `database.dataPath`, so Serverpod starts and manages the test database (an embedded PostgreSQL) itself, and the project's `docker-compose.yaml` is not used for it. Just run `dart test` in the server package.

Checklist after doing changes, in this order:

- `dart analyze` (CLI)
- `dart format` (CLI)
- `create_migration` and `apply_migrations` (MCP - only if necessary)
- Do `serverpod` MCP `hot_restart` if required (hot reload is done automatically)
- Run tests, if applicable (`dart test` in the server package)
- Check `serverpod` MCP `tail_server_logs` for any issues.

## Push backend notes

- **FCM credentials** load, in order, from `FIREBASE_SERVICE_ACCOUNT_JSON`,
  `FIREBASE_SERVICE_ACCOUNT_FILE`, `config/firebase_service_account_key.json`,
  or any `config/*firebase-adminsdk*.json` (all gitignored). Never commit them.
- `PUSH_KINDS`, `PUSH_BOOTSTRAP_RELAY` and `PUSH_RELAYS` tune the forwarder (see
  `docs/push.md`).
- The tests cover the signed registration protocol, the relay `#p` filters, the
  dispatcher (forward-as-is, recipient filtering, dead-token deletion) and the
  endpoint against a real database.
