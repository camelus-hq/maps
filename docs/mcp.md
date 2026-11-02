# OpenMaps MCP server (`openmaps_cli`)

`tool/openmaps_cli` is a small, pure-Dart (no Flutter) **stdio MCP server** that exposes the
OpenMaps control surface to MCP clients (agents). It gives agents a stable tool surface so the
driving workflow is *drive → screenshot → compare → fix* (AGENTS.md §Driving the app).

## Run it (bridge mode)

1. Launch the app with the control channel (debug/profile only):

   ```sh
   flutter run --control 7981            # or, for an installed build:
   adb shell am start -n app.camelus.maps/.MainActivity --es openmaps.control.port 7981
   adb forward tcp:7981 tcp:7981
   ```

2. Point the MCP server at it:

   ```sh
   dart run tool/openmaps_cli/bin/openmaps_cli.dart mcp --connect 127.0.0.1:7981
   ```

   With several devices attached, pass `--serial <adb-serial>` (used for the screenshot capture).

Example MCP client configuration:

```json
{
  "mcpServers": {
    "openmaps": {
      "command": "dart",
      "args": ["run", "tool/openmaps_cli/bin/openmaps_cli.dart", "mcp", "--connect", "127.0.0.1:7981"]
    }
  }
}
```

## Tools

| Tool | Arguments | Result |
|---|---|---|
| `openmaps_list_commands` | — | the live command registry (`id` + `description`) |
| `openmaps_execute` | `{method, params?}` | dispatches any command id — the same path a tap takes |
| `openmaps_state` | — | app snapshot (ready, build mode, camera, style, traffic, config flags) |
| `openmaps_screenshot` | `{path?}` | a PNG **image** block (adb `screencap`, which includes the Mapbox platform view); falls back to the in-app `ui.screenshot` path |

`openmaps_execute` is the workhorse: every user-visible action is a command id (search, place,
route, nav, map, layers, `ui.*` synthetic input), so an agent never needs a gesture. See
[`control-protocol.md`](control-protocol.md) for the full command list.

Synthetic input goes through the same registry:

```json
{"name":"openmaps_execute","arguments":{"method":"ui.tap","params":{"x":70,"y":115}}}
{"name":"openmaps_execute","arguments":{"method":"ui.swipe","params":{"fromX":205,"fromY":850,"toX":205,"toY":400}}}
{"name":"openmaps_execute","arguments":{"method":"ui.back"}}
```

## Modes

- **Bridge** (`--connect host:port`) — drives a real app through the JSON-lines control channel.
  Works today and is what the parity loop uses.
- **Headless** — *not implemented yet.* The plan (M9.3) wants a mode that "runs the app logic
  against `data/fakes/` — no emulator, no keys". The obstacle: the command registry lives in the
  Riverpod/Flutter state layer (`flutter_riverpod` → `dart:ui`), so it cannot run in a plain
  `dart run` process. Options considered:
  1. run the CLI as a Flutter tool under the Flutter SDK (headless engine), or
  2. make the state/command core Flutter-free (pure-Dart `riverpod`) so `dart run` works.

  The tool surface is identical in both modes, so choosing (1) or (2) does not change agent
  workflows. `--headless` currently exits with a clear message rather than pretending to work.

## Acceptance

`tool/openmaps_cli/acceptance/mcp_flow.py` drives one complete flow **entirely through MCP** — the
handshake, `openmaps_state`, `openmaps_list_commands`, then `search.query` → `place.select` →
`route.plan` → `nav.start {live}` → `openmaps_screenshot` → `nav.stop` — against the live app:

```sh
adb shell am start -n app.camelus.maps/.MainActivity --es openmaps.control.port 7981
adb forward tcp:7981 tcp:7981
python3 tool/openmaps_cli/acceptance/mcp_flow.py
```

## Notes

- The server is transport-agnostic internally (`McpServer.handleLine`), so it is unit-tested
  without a process or socket (`test/tool/mcp_server_test.dart`).
- It never enables anything in a release build: it only talks to a control channel that the app
  itself refuses to start in release (`lib/main.dart`, `kReleaseMode` guard).
