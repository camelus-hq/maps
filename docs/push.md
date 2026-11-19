# Push notifications

OpenMaps can be woken by a push when something happens for **you** — a friend
starts sharing their location, or you get a direct message — without a relay
learning who you are. The server (`maps_api/`, see `maps_api/docs/push.md`)
forwards only **NIP-59 gift wraps** addressed to your public key; FCM/APNs never
see the message.

```
friend's app ──gift wrap──▶ relay ──▶ maps_api server ──data-only──▶ FCM ─┬─▶ app (foreground)
                                                                         └─▶ background isolate
                                                                              decrypt → local notification
```

## Transport

**Firebase Cloud Messaging** is used. Only `firebase_messaging` +
`firebase_core` are pulled in; no analytics/crashlytics or other Google library.

> The server also supports **UnifiedPush**, selected by supplying an `https://`
> endpoint as the token, but the app does not use that transport: the Dart
> `unifiedpush` package's transitive Android dependencies were incompatible with
> the project's AGP 9 toolchain. Adding it is a client-only change once a
> compatible package exists; the server side needs no change.

Settings → **Notifications** holds the transport picker (**Firebase** / **Off**,
stored as `AppSettings.pushTransport`) and a **status** row that reports whether
push is configured, supported, allowed, has a token and is registered on the
server. Registration is automatic; when it cannot complete the row shows the
concrete reason (signed out, permission refused, no token, server refusal) and
tapping it re-runs the sync (`PushNotificationsController.refresh`, exposed to
agents as `app.pushStatus` with `refresh: true`).

## Configuration

| Where | What |
|---|---|
| `--dart-define=PUSH_SERVER_URL=https://api.example.com` | Base URL of the Serverpod backend. Defaults to `https://api.map.camelus.app`. |
| `android/app/google-services.json` | Firebase Android config. **Gitignored**; the gradle plugin is applied only when the file exists, so a clone without keys still builds. |
| `ios/Runner/GoogleService-Info.plist` | Firebase iOS config. **Gitignored**; add it to the **Runner** target in Xcode. |
| `maps_api_server/config/firebase_service_account_key.json` | Server-side FCM sender key. **Gitignored**; see the server doc. |

Register relays default to the live-share relay set
(`AppConfig.liveShareRelays`), and the outer kind subscribed is `1059` (a gift
wrap).

### Firebase Installation IDs (FID)

Firebase deprecated FCM registration tokens in favour of **Firebase Installation
IDs**. `firebase_messaging` 17 uses the new API (`register()` / `onRegistered`),
but FID registration is **opt-in** and, without the flag, `register()` throws
`IllegalStateException: API disabled`. Both are checked in:

| Platform | Where | Value |
|---|---|---|
| Android | `android/app/src/main/AndroidManifest.xml` (`<application>`) | `<meta-data android:name="firebase_messaging_installation_id_enabled" android:value="true" />` |
| iOS | `ios/Runner/Info.plist` | key `FirebaseMessagingInstallationIdEnabled` = `true` |

The value registered with the server is the FID. FCM's `token` field (which the
sender uses) accepts an FID during Firebase's transition period; the sender can
later move to the dedicated `fid` field.

### iOS, once

1. Add `Runner/GoogleService-Info.plist` to the Xcode project (Runner target).
2. Enable the **Push Notifications** capability (adds the `aps-environment`
   entitlement) and **Background Modes → Remote notifications**.
   `remote-notification` is already in `UIBackgroundModes`; the entitlement needs
   Xcode (signing).

## What runs where

* `PushRegistrationBootstrap` (`lib/state/`) initializes FCM and keeps the
  registration in sync: register on sign-in, re-register on token rotation, and
  on sign-out it invalidates the device token so the server stops delivering to
  the old identity. It is owned by `pushStatusProvider` and kept alive by the
  invisible `PushNotificationLayer` in the map home.
* **Foreground session**: while the app is open it holds a **streaming**
  connection to the server (`client.push.foreground`) that tells it to **pause**
  forwarding — the app is receiving gift wraps on its own relay subscription, so
  a push would only duplicate. The stream ends (and forwarding resumes) when the
  app goes to the background or the socket times out. Because the app is then the
  receiver, `SocialService.incomingPushes` feeds decrypted wraps back into the
  same notification bridge (`PushNotificationContent`), so a **direct message**
  and a **live-share start** still notify.
* `PushRegistrar` (`lib/data/notifications/`) signs a proof event with your
  Nostr identity and calls the server's `push.register`, carrying the token, the
  transport and the relays; `foreground()` opens the pause session the same way.
* `pushBackgroundHandler` is the `@pragma('vm:entry-point')` entry point FCM
  runs in a **separate isolate** for a data-only message. It:
  1. **attaches** to the same ObjectBox store the running app has open
     (`openAppDatabaseAttached` → `Store.attach`, falling back to a normal open
     if the app is not running) — this is what lets the two isolates share the
     database;
  2. restores the Nostr account from secure storage (a plugin, so it works in
     the background engine too);
  3. unwraps the gift wrap with `ndk.giftWrap.fromGiftWrap`;
  4. maps the rumor through `PushNotificationContent` and shows a notification
     with the first-party `openmaps_notifications` plugin.
* `openmaps_notifications` (`plugins/openmaps_notifications/`) is a local
  **plugin** rather than a channel in `MainActivity`, because only plugins are
  registered on the background engine that FCM creates — a `MainActivity`
  channel is unreachable there.

## Supported kinds

Only kinds the app understands produce a notification; anything else is
deliberately ignored (a relay/app cannot make the app pop an arbitrary alert).

| Inner (decrypted) kind | Notification |
|---|---|
| `20510` (live location) | "<name> is sharing their location with you" — only the session **`start`**, so a stream of position updates does not spam |
| `14` (NIP-17 direct message) | "<name>: <text>" |

A live-share rumor carries a type: `start` (the first payload of a session),
`update` (a later position) or `stop`. Only `start` notifies; `update`/`stop`
just move or drop the pin.

## Tests

`test/data/push_notification_content_test.dart`,
`test/data/live_location_payload_test.dart`,
`test/data/push_registrar_test.dart` and
`test/state/push_notifications_test.dart` cover the decrypted-kind mapping, the
start-only notification rule, the signed registration, the foreground session
and the register/unregister lifecycle with fakes.
