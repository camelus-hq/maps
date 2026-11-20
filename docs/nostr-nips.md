

### Tags

| Tag | R | Value |
|---|---|---|
| `d` | required | Place key, e.g. `openstreetmap:way/123456789` (≤ 256 chars of id) |
| `rating` | required | Normalised rating `0`–`1`, written without trailing zeros (`"0.8"`, `"1"`, `"0.96"`) — multiply by 5 for stars |
| `client` | recommended | `maps`; marks events this app produced |
| `g` | required | Geohash of the place at **every precision from 9 down to 1** (full point plus all enclosing prefixes) |

The stack of `g` tags is what makes viewport queries cheap: a client can ask a
relay for one coarse cell (`#g: ["u33d"]`) and receive every review inside it in
a single round trip, at any zoom level.



### Example event

```json
{
  "id": "<event-id>",
  "pubkey": "<author-pubkey>",
  "created_at": 1730000000,
  "kind": 31987,
  "tags": [
    ["d", "openstreetmap:way/123456789"],
    ["rating", "0.8"],
    ["client", "openmaps"],
    ["g", "u33dbtq4w"],
    ["g", "u33dbtq4"],
    ["g", "u33dbtq"],
    ["g", "u33dbt"],
    ["g", "u33db"],
    ["g", "u33d"],
    ["g", "u33"],
    ["g", "u3"],
    ["g", "u"]
  ],
  "content": "Good coffee and fast Wi-Fi.\n\nhttps://blossom.primal.net/<sha256>.jpg",
  "sig": "<signature>"
}
```

### Reading

- **One place:** `{"kinds":[31987],"#d":["openstreetmap:way/123456789"]}`.
- **A viewport:** `{"kinds":[31987],"#g":["<cell>", …]}` with up to ~8 covering
  cells at geohash precision ≤ 7 (≈150 m cells). A viewport too wide to cover
  falls back to a plain kind query, and the client clips to the map bounds.
- The longest valid `g` tag is decoded back to the place coordinate.

### Robustness (hostile input)

Wrong kinds, missing/oversized `d`/`g`/`rating`, out-of-range ratings,
non-finite numbers, unknown or malformed geohashes, content over 8000 chars and
more than 10 photo links are all dropped rather than trusted.





## Proposal 2 — Live location update (`kind: 20510`, inside a NIP-59 gift wrap)

The same `20510` rumor is carried in one of **two** outer NIP-59 gift wraps:

| Outer kind | Carries | Storage | Forwarded by the push server |
|---|---|---|---|
| `1059` (regular gift wrap) | session `start` and `stop` | stored by relays | **yes** — reaches a closed app as a push |
| `21059` (ephemeral gift wrap) | position `update` (and any in-session refresh) | relays MUST NOT store it | no — live-only, received by a listening app |

Splitting the two keeps the useful, low-volume events (a friend started / stopped sharing) deliverable while the app is closed, and keeps the high-volume position stream out of storage, out of the push fan-out, and free of the "old update surfaces late" problem.



### Tags (on the rumor)

| Tag | R | Value |
|---|---|---|
| `p` | required | One per recipient pubkey (the friends who may see the location) |
| `t` | required | `openmaps-live-location` — lets a recipient ignore unrelated kinds |
| `d` | recommended | The live-share `<session-id>`; one session = one id |

### Content (rumor)

A small, versioned JSON object (schema version `1`):

| Field | Type | Meaning |
|---|---|---|
| `v` | int | Schema version (`1`) |
| `t` | string | `"start"` (a session's first payload), `"update"` (a later position), or `"stop"` (the session ended early). A `start`/`stop` goes in a stored `1059` wrap, an `update` in an ephemeral `21059` wrap. |
| `session` | string | Session id (≤ 64 chars); must match the `d` tag |
| `at` | int | Unix **seconds** when the position was sampled |
| `exp` | int | Unix **seconds** when the session ends on its own |
| `lat`, `lon` | number | Position (float degrees); omitted on a `stop` |
| `acc` | number | Optional accuracy in metres (`0`–`100000`) |
| `hdg` | number | Optional heading in degrees (`0`–`360`) |

The sender's **name and avatar are not in the payload**: a recipient resolves
them from the sender's Nostr profile (`kind: 0`), exactly as it does for the
friends list. The wire stays minimal, and an identity is always a real published
profile rather than a self-asserted string.

### Example rumor (position update)

```json
{
  "kind": 20510,
  "pubkey": "<sender-pubkey>",
  "created_at": 1730000000,
  "tags": [
    ["p", "<recipient-pubkey-1>"],
    ["p", "<recipient-pubkey-2>"],
    ["t", "openmaps-live-location"],
    ["d", "<session-id>"]
  ],
  "content": "{\"v\":1,\"t\":\"update\",\"session\":\"<session-id>\",\"at\":1730000000,\"exp\":1730001800,\"lat\":52.52,\"lon\":13.405,\"acc\":9,\"hdg\":180}"
}
```

The rumor has an `id` but **no `sig`** — it is unsigned; the seal inside the wrap
is what authenticates the sender.

### Example rumor (session stopped early)

```json
{
  "kind": 20510,
  "pubkey": "<sender-pubkey>",
  "created_at": 1730000600,
  "tags": [
    ["p", "<recipient-pubkey-1>"],
    ["t", "openmaps-live-location"],
    ["d", "<session-id>"]
  ],
  "content": "{\"v\":1,\"t\":\"stop\",\"session\":\"<session-id>\",\"at\":1730000600,\"exp\":1730001800}"
}
```

A `stop` may omit `lat`/`lon`; recipients drop the pin immediately instead of
waiting for `exp`.

### Example wire events (what a relay holds)

A session **start** or **stop** is a **stored** gift wrap (`kind: 1059`):

```json
{
  "id": "<event-id>",
  "pubkey": "<random-ephemeral-pubkey>",
  "created_at": 1730000000,
  "kind": 1059,
  "tags": [
    ["p", "<recipient-pubkey-1>"]
  ],
  "content": "<encrypted>",
  "sig": "<signature>"
}
```

A position **update** is an **ephemeral** gift wrap (`kind: 21059`); a relay
must not store it, so it exists only for whoever is subscribed at that moment:

```json
{
  "id": "<event-id>",
  "pubkey": "<random-ephemeral-pubkey>",
  "created_at": 1730000100,
  "kind": 21059,
  "tags": [
    ["p", "<recipient-pubkey-1>"]
  ],
  "content": "<encrypted>",
  "sig": "<signature>"
}
```

One wrap is published **per recipient**, each with its own throwaway key, so two
friends cannot correlate a share by the envelope's author.

### Subscribing

A recipient subscribes to **both** outer kinds — the stored start/stop and the
ephemeral updates:

```json
{"kinds": [1059, 21059], "#p": ["<recipient-pubkey>"]}
```

and unwraps each result. Anything that is not a `20510` rumor, is not from a
valid sender pubkey, or fails to decode is ignored.

Separately, the **push server** watches only `1059` (never `21059`) and forwards
the stored wraps to a registered device while the app is closed, so the app
still learns a session started or stopped. It then pauses forwarding while the
app is in the foreground, because the app already receives both kinds on its own
live subscription.



---

## Appendix — published NIPs the app relies on

These are standard, not proposals:

| NIP | Use in OpenMaps |
|---|---|
| NIP-01 | Base event/serialisation; `client` tag convention |
| NIP-02 | Contact list (`kind: 3`) — "people you follow", for adding friends |
| NIP-19 | `npub…`/`nsec…` bech32 keys (QR codes, sign-in) |
| NIP-51 | **Friends set** — categorized people set `kind: 30000` named `friends`; the keys live in the NIP-44 encrypted content, so relays never learn who your friends are |
| Profile metadata (`kind: 0`) | Friend names and avatars |
| NIP-44 + NIP-59 | Encryption and gift wrap used by live share and DMs; the live-share **updates** use the ephemeral gift wrap `kind: 21059`, which relays do not store |
| NIP-17 | Private, gift-wrapped direct messages between friends (message rumor `kind: 14`, DM relay list `kind: 10050`) |
| NIP-17 file messages (`kind: 15`, AES-256-GCM) | In-app feedback: the screenshot is encrypted (fresh key + nonce, the Amethyst convention) before it is uploaded to Blossom and sent as a gift-wrapped file message |
| Blossom (BUD-02) | Photo uploads for reviews; `kind: 24242` auth event |
