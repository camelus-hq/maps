# iOS target

OpenMaps builds for iOS from the standard Flutter `ios/` project
(`app.camelus.maps`, deployment target **iOS 15.0**). Plugins are resolved
with **Swift Package Manager** — there is no `Podfile`.

## Build prerequisites (owner setup, never committed)

- **Mapbox secret downloads token.** The `mapbox_maps_flutter` iOS SDK fetches
  `mapbox-maps-ios` over Swift Package Manager, which is gated behind a Mapbox
  account token with the **`Downloads:Read`** scope. Put it in `~/.netrc`
  (outside the project, `chmod 600`):

  ```
  machine api.mapbox.com
    login mapbox
    password <MAPBOX_DOWNLOADS_TOKEN>
  ```



- Apple signing: open `ios/Runner.xcworkspace` in Xcode and select a team for
  the `Runner` target (bundle id `app.camelus.maps`).

## Info.plist permissions

iOS terminates an app that requests a permission without a matching usage
string, so `ios/Runner/Info.plist` declares all of them:

| Key | Used by |
|---|---|
| `NSLocationWhenInUseUsageDescription` | geolocator (my location, follow, guidance), the Mapbox user puck, the compass heading |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | keeping guidance / a live-location share alive when the user grants "Always" |
| `NSCameraUsageDescription` | `mobile_scanner` (QR codes for adding friends / signing in) |
| `NSPhotoLibraryUsageDescription` | `image_picker` (attaching a photo to a place review) |
| `UIBackgroundModes: location` | background position updates while navigating or sharing |

`UIBackgroundModes: location` is the iOS counterpart of the Android location
**foreground service**: it lets turn-by-turn guidance and an active live-location
share keep receiving fixes with the app backgrounded.
`GeolocatorLocationService` therefore uses `AppleSettings` with
`allowBackgroundLocationUpdates: true` on iOS (and `AndroidSettings` elsewhere) —
see `buildLocationSettings`.

## Platform features that are Android-only

These already degrade gracefully on iOS (the ports return `false`/no-op rather
than throwing), so the app runs without them:

- **In-app self-update** — it installs an APK, so `lib/app/di.dart` wires the
  release manifest and installer only on Android; the iOS App Store handles
  updates instead.
- **Ongoing notices** — the navigation and live-share `MethodChannel`s
  (`openmaps/navigation`, `openmaps/live_share`) are implemented natively in
  `MainActivity`; on iOS the calls are caught and the notices are simply not
  shown (`NavigationForegroundService` has no iOS equivalent).
- **Native window screenshot** — the `openmaps/screenshot` channel is Android
  only; `captureAppPng` falls back to the Flutter repaint boundary and
  composites the live map in from the Mapbox snapshot.
- **`--control` entrypoint arg** — `MainActivity` bridges it from an `Intent`
  extra on Android; on iOS pass it via the Xcode scheme's "Arguments Passed On
  Launch" (debug/profile builds only).

## Continuous integration

`.github/workflows/build_ios.yaml` builds a signed App Store `.ipa` on a
`macos-26` runner with [fastforge](https://fastforge.dev) (`distribute_options.yaml`,
release `appstore`) and uploads it to App Store Connect (**TestFlight**) on every
published GitHub Release or on manual dispatch. It also attaches the `.ipa` to the
Release and uploads the obfuscation symbols (`build/ios/symbols`) as a workflow
artifact.

### Required repository secrets

Set these under **Settings → Secrets and variables → Actions**. Nothing here is
committed.

| Secret | What it is |
|---|---|
| `MAPBOX_DOWNLOADS_TOKEN` | Mapbox **secret** token with the `Downloads:Read` scope (the same one Android uses for the Maven repo). Written to `~/.netrc` so SPM can fetch `mapbox-maps-ios`. |
| `DART_DEFINES_JSON_BASE64` | base64 of the repo's `.dart-define.json`. |
| `IOS_CERTIFICATE_BASE64` | base64 of an **Apple Distribution** certificate exported as `.p12` (with its private key). |
| `IOS_CERTIFICATE_PASSWORD` | Password of that `.p12`. **Optional** — leave unset for a passwordless certificate. |
| `IOS_PROVISION_PROFILE_BASE64` | base64 of the **App Store** provisioning profile (`.mobileprovision`) for `app.camelus.maps`. |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key **Key ID**. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API **Issuer ID**. |
| `APP_STORE_CONNECT_API_KEY_BASE64` | base64 of the `AuthKey_<KEY_ID>.p8` file (upload only). |

```sh
base64 < .dart-define.json         | tr -d '\n'   # → DART_DEFINES_JSON_BASE64
base64 < distribution.p12          | tr -d '\n'   # → IOS_CERTIFICATE_BASE64
base64 < AppStore.mobileprovision  | tr -d '\n'   # → IOS_PROVISION_PROFILE_BASE64
base64 < AuthKey_XXXXXXXXXX.p8     | tr -d '\n'   # → APP_STORE_CONNECT_API_KEY_BASE64
```

### Signing

The Xcode project is committed with **manual** signing for the `Release` and
`Profile` configurations:

| Setting | Value |
|---|---|
| `CODE_SIGN_STYLE` | `Manual` (Release + Profile; `Debug` stays `Automatic` for `flutter run`) |
| `CODE_SIGN_IDENTITY[sdk=iphoneos*]` | `Apple Distribution` |
| `PROVISIONING_PROFILE_SPECIFIER` | `maps` (the App Store profile's name) |
| `DEVELOPMENT_TEAM` | `5H4429Z686` |

The runner only needs the matching assets installed: the **Apple Distribution**
certificate (`.p12`, imported into the keychain) and the App Store profile
(`.mobileprovision`). The profile is copied to **both** directories, because
`xcodebuild` and Flutter look in different places:

- `~/Library/MobileDevice/Provisioning Profiles` — used by `xcodebuild` (archive).
- `~/Library/Developer/Xcode/UserData/Provisioning Profiles` — scanned by
  `flutter build ipa` when it generates the `ExportOptions.plist`.

Flutter then detects manual signing and generates the matching export options
(`signingStyle = manual` + the `provisioningProfiles` mapping) for the App Store
export. No Apple ID account is needed.

> Automatic signing can't be used here: `flutter build ipa` runs `xcodebuild`
> with `-allowProvisioningUpdates`, which requires an Apple ID account on the
> runner ("No Accounts: Add a new account"), and Flutter never passes an App Store
> Connect API key (`-authenticationKeyPath/-ID/-IssuerID`) to `xcodebuild`. The
> `.p8` in `~/private_keys` is only used by the `xcrun altool` upload.

How to obtain the two files (Apple Developer portal → Certificates, Identifiers
& Profiles, team `5H4429Z686`):

1. **App ID** `app.camelus.maps` must exist (register it if not).
2. **Certificates → + → Apple Distribution** → create, download, open in Keychain
   Access, then export the certificate **and its private key** as a `.p12`. Set a
   password or leave it empty; if you set one, store it as
   `IOS_CERTIFICATE_PASSWORD` (otherwise omit that secret).
3. **Profiles → + → App Store** → select the App ID and the distribution
   certificate → download the `.mobileprovision`.

