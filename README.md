# Camelus Maps

Camelus Maps, open map data with social features, built for exploring.

Features/Focus:
 - reviews over nostr
 - live share with friends (e2e encrypted)
 - social bounds (public private)
 - Routing focused on pedestrians, bikes, and public transport.
 - Optimized for European-style cities (mixed traffic)

## Running

```sh
flutter run --flavor direct --dart-define=APP_FLAVOR=direct -d <device>
```

Android builds have two distribution flavors: `direct` (signed with the app's
own key, and the only one that self-updates) and `play` (signed with the upload
key for Google Play). `flutter run`/`flutter build` must select one with
`--flavor`; pass `APP_FLAVOR=direct` too so the self-updater is wired. Drop both
on iOS/desktop/web (their scheme is not flavored).

The app runs keyless on in-memory fakes. Real backends are selected at bootstrap
from `--dart-define` values (e.g. `MAPBOX_TOKEN`, `VALHALLA_URL`)