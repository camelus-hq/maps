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
flutter run -d <device>
```

The app runs keyless on in-memory fakes. Real backends are selected at bootstrap
from `--dart-define` values (e.g. `MAPBOX_TOKEN`, `VALHALLA_URL`)