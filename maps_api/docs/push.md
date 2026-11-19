# Push notifications (server)

The server is a **privacy-preserving forwarder**: it watches Nostr relays for
events addressed to registered identities and delivers them to the device over
Firebase Cloud Messaging (default) or UnifiedPush — always as an opaque NIP-59
gift wrap, so neither FCM/APNs nor the UnifiedPush distributor can read the
message.

```
   sender ──gift wrap──▶ relay ──▶ PushService (this server)
                                       │  #p filter: only registered keys
                                       ├─ firebase    ─▶ FCM ─▶ device
                                       └─ unifiedpush ─▶ ntfy ─▶ device
                                                              │
                                          background isolate ─┘ decrypt + notify
```

## What it does

* **Listens** on the bootstrap relays plus every relay a client registers on,
  with a `#p` filter for exactly the registered public keys (`buildPushFilters`),
  so it never receives the relay's whole gift-wrap firehose.
* **Filters** each event by the recipient's registered outer kinds, and drops
  hellthreads (more than `maxPubkeyPerEvent` `p` tags).
* **Forwards** a gift wrap (`kind 1059`) **unchanged** — the server cannot read
  it. Any other supported kind is gift-wrapped by the server first, so FCM/APNs
  still only ever carry ciphertext.
* **Deletes** tokens the transport reports as dead.
* **Pauses** forwarding to an identity while its app is in the foreground and
  holding a `foreground` stream open: the app is receiving gift wraps on its own
  relay subscription then, so a push would only duplicate it.

## Endpoint (`client.push`)

Registration is authenticated by a **signed Nostr event** (BIP-340 verified), not
a Serverpod account: the identity *is* the public key. The token rides in the
event's tags, so the signature covers it.

| Method | Arguments | Returns |
|---|---|---|
| `register` | `registrationJson` — a signed event | `bool` |
| `getState` | `proof` — any signed event by the identity | `PushRegistrationState` |
| `unregister` | `proof`, optional `token` | `bool` |
| `foreground` | `proof` — any signed event by the identity | `Stream<String>` |

`foreground` is a **streaming method**: the client keeps it open while the app is
in the foreground. While it is open the forwarder skips that identity
(`PushDispatcher` consults an in-memory `PushPresence`). The stream ends when the
client cancels it (app backgrounded) or Serverpod's websocket ping times a dead
connection out (30 s) — then forwarding resumes, and `PushPresence` is cleared.

Tags understood by `register`:

| Tag | Meaning |
|---|---|
| `["push-token", "<token>"]` | FCM registration token, or a UnifiedPush endpoint URL. **Required.** `["challenge", …]` is accepted as a legacy alias. |
| `["relay", "wss://…"]` | A relay to watch for this identity. **At least one required** (ws/wss only, capped). |
| `["kind", "1059"]` | An outer kind to push. Defaults to all available kinds. |
| `["push-transport", "firebase"｜"unifiedpush"]` | Optional; the token shape is authoritative (a URL ⇒ UnifiedPush, else FCM). |

The transport is therefore chosen by **the token the client supplies**: an FCM
token uses Firebase, a UnifiedPush endpoint URL uses UnifiedPush.

## Configuration (environment)

| Variable | Default | Purpose |
|---|---|---|
| `PUSH_KINDS` | `1059` | Comma-separated outer kinds to watch/forward. |
| `PUSH_BOOTSTRAP_RELAY` | `wss://relay.map.camelus.app` | One relay always watched. |
| `PUSH_RELAYS` | – | Extra relays always watched. |

## Firebase (FCM) credentials

Only the **Messaging** scope is requested and only `messages:send` is called; no
other Google API is reachable, and no Google library is used by the app beyond
`firebase_messaging`.

The sender loads credentials in this order:

1. `FIREBASE_SERVICE_ACCOUNT_JSON` — the service-account JSON contents.
2. `FIREBASE_SERVICE_ACCOUNT_FILE` — a path to that file.
3. `config/firebase_service_account_key.json` — **gitignored**, for local dev.
4. Application Default Credentials (`GOOGLE_APPLICATION_CREDENTIALS`), with
   `FIREBASE_PROJECT_ID` set.

If none are present, FCM sends fail with a logged reason; the server keeps
running and UnifiedPush still works. **Never commit the service account key.**

Example for local development:

```bash
cp <downloaded-service-account>.json maps_api_server/config/firebase_service_account_key.json
```

## UnifiedPush

A UnifiedPush endpoint is just an `https://…` URL supplied as the `push-token`.
The server `POST`s the wrapped event as the request body (the same shape ntfy
accepts). A `404`/`410` deletes the endpoint.

## Tests

`dart test` in `maps_api_server` covers the protocol (signature verification and
tag parsing), the relay filters, the dispatcher (forward-as-is, recipient
filtering, foreground pause, dead-token deletion) and the endpoint against a real
database.
