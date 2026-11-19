# maps_api_client

Generated Serverpod client for the OpenMaps push backend. **Do not edit** — the
whole package is rewritten by `serverpod generate`.

The OpenMaps app at the repository root depends on this package and calls
`client.push.register(...)` / `getState` / `unregister` to register its device.
