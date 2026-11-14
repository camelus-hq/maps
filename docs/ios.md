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

