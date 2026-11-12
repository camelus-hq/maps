# OpenMaps control protocol

The debug/profile builds expose a JSON-lines control channel so agents can drive
every action programmatically (AGENTS.md §Driving the app). This document is
hand-maintained until M9.4 generates it from the registry.

## Transport

- TCP on `127.0.0.1` (localhost only), started with `--control <port>`
  (e.g. `flutter run --control 7981`). **Never enabled in release builds.**
- On Android, `adb` cannot set the embedding's serializable entrypoint-args
  extra, so `MainActivity` bridges a plain string extra instead:

  ```sh
  adb shell am start -n app.camelus.maps/.MainActivity \
      --es openmaps.control.port 7981
  ```

- One JSON object per line.
- Request: `{"id":1,"method":"<id>","params":{…}}`
- Success: `{"id":1,"result":…}`
- Failure: `{"id":1,"error":{"code":"…","message":"…"}}` — the connection is
  never closed or crashed by bad input.

From the host to an emulator app:

```sh
adb forward tcp:7981 tcp:7981
```

## Commands

| id | params | result |
|---|---|---|
| `session.list` | — | array of `{id, description}` |
| `session.help` | `{\"id\": \"…\"}` (optional) | one or all command descriptions |
| `app.ready` | — | `true` once the app is running |
| `app.state` | — | `{ready, buildMode, config, camera, style, traffic}` |
| `map.camera.get` | — | `{lat, lon, zoom, bearing, tilt}` |
| `map.camera.set` | `{lat, lon, zoom?, bearing?, tilt?}` | the new camera |
| `map.resetBearing` | — | the camera with `bearing: 0` (locks north-up while following) |
| `map.orientation` | `{mode?: north\|heading}` (omit to toggle) | the mode name — direction-up vs north-up while following |
| `map.myLocation` | — | the camera moved to the last known fix |
| `map.location` | — | `{hasFix, streaming, lost, lat, lon, bearing, accuracy, speed}` — the live device-location state; `lost` means location services are off or permission was denied (never inferred from a quiet stream) |
| `map.followMyLocation` | — | the new follow state (boolean) |
| `map.follow` | `{on}` | the new follow state (boolean) |
| `map.style.set` | `{style: standard\|satellite\|terrain}` | the style name |
| `map.style.get` | — | the current style name |
| `map.traffic` | `{on?}` | the overlay state (boolean); omitting `on` toggles |
| `map.markers.set` | `{markers: [{id, lat, lon}]}` | `{count}` |
| `map.markers.get` | — | the current markers |
| `map.markers.clear` | — | `{count: 0}` |
| `search.query` | `{text}` | array of places |
| `place.select` | `{id}` | the selected place (focusses the map) |
| `place.clear` | — | `true` |
| `place.bookmarks` | — | array of saved places |
| `place.bookmark` | `{id, bookmarked?}` | the saved state (boolean) |
| `place.copyAddress` | `{id?}` (defaults to the selected place) | `{id, address}` — also copied to the clipboard |
| `review.compose` | `{id?}` (defaults to the selected place) | the review draft state |
| `review.compose.close` | — | `true` |
| `review.draft.set` | `{rating?: 0..1, stars?: 1..5, text?, visibility?: public\|friends}` | the review draft state |
| `review.photo.add` | `{path}` or `{base64, mimeType?}` | the review draft state |
| `review.publish` | — | the review draft state (publishes kind 31987) |
| `review.list` | `{id?}` (defaults to the selected place) | the place review summary |
| `review.open` | `{placeKey?}` or `{id?}`, `focus?` | the opened place |
| `map.reviews` | — | the review badges on screen |
| `map.reviews.friendOnly` | `{on?}` | the new state (boolean) |
| `review.helpful` | `{id, helpful?}` | the new helpful state (boolean) |
| `review.copy` | `{text}` | the copied text |
| `route.request` | `{origin:{lat,lon}, destination:{lat,lon}, mode?}` | array of routes |
| `route.plan` | `{id}` | the selected route |
| `route.mode` | `{mode: drive\|walk\|cycle}` | the mode name |
| `route.select` | `{index}` | the index |
| `route.clear` | — | `true` |
| `route.origin` | `{id}` | the selected route |
| `route.destination` | `{id}` | the selected route |
| `route.addStop` | `{id}` | `true` |
| `route.setStop` | `{index, id}` | the selected route |
| `route.swap` | — | `true` |
| `route.editEndpoint` | `{field: origin\|destination\|stop, index?}` | `{field, index?}` — opens the place picker |
| `route.endpoint.close` | — | `true` |
| `route.useCurrentLocation` | `{field?: origin\|destination\|stop, index?}` | the selected route |
| `route.pickOnMap` | `{field: origin\|destination\|stop, index?}` | `true` (then long-press the map) |
| `nav.start` | `{index?, auto?, live?}` | the guidance state (needs a planned route) |
| `nav.position` | `{lat, lon, heading?, speed?}` | the guidance state |
| `nav.step` | `{meters?, speed?}` | the guidance state |
| `nav.state` | — | the guidance state |
| `nav.stop` | — | `true` |
| `nav.overview` | — | the guidance state (fit whole route vs tracking) |
| `nav.mode` | `{mode: drive\|walk\|cycle\|transit}` | the guidance state — re-skins the navigation UI |
| `nav.notification` | — | the ongoing trip notification `{visible, title, body, progress, statusChip, mode}` |
| `ui.tap` | `{x, y}` | `true` — synthetic tap at logical coordinates |
| `ui.swipe` | `{fromX, fromY, toX, toY}` | `true` — synthetic drag |
| `ui.scroll` | `{x, y, dx, dy}` | `true` — synthetic scroll by (dx, dy) |
| `ui.back` | — | `true` — system back gesture (pop, else go home) |
| `ui.screenshot` | `{path?}` | `{path, bytes}` — PNG written to the app filesystem |

## Example session

```sh
adb forward tcp:7981 tcp:7981
printf '%s\n' \
  '{"id":1,"method":"session.list"}' \
  '{"id":2,"method":"app.state"}' \
  '{"id":3,"method":"map.camera.set","params":{"lat":52.52,"lon":13.405,"zoom":14}}' \
  | nc 127.0.0.1 7981
```

`ui.screenshot` captures the Flutter frame via a repaint boundary. Once the
Mapbox platform view lands (M2) this moves to a native capture channel, with
`adb exec-out screencap` as the cross-check.

## Command index (generated)

The table below is generated from the live command registry. **Do not edit by hand** — run
`UPDATE_PROTOCOL_DOC=1 flutter test test/control/control_protocol_doc_test.dart` to refresh, and the
sync test fails if it drifts from the registry.

<!-- BEGIN GENERATED COMMANDS -->
| id | description |
|---|---|
| `app.db` | Report the local database (schema version, open state, metric count, setting keys); optionally record a metric or clear the log (params: {record: {name, value?, labels?}, clearMetrics?}). |
| `app.onboarding` | Get or set the onboarding-seen flag (params: {seen?}); returns it. |
| `app.ready` | Return true once the app is running. |
| `app.settings` | Return app settings (distance unit, theme, search provider, developer options). |
| `app.settings.set` | Update app settings (params: {unit?: metric\|imperial, theme?: system\|light\|dark, showOsmTags?: bool, searchBackend?: mapbox\|openstreetmap\|camelus}). |
| `app.state` | Dump serialisable app state. |
| `app.tab` | Select the map-home bottom-nav tab (params: {tab: explore\|you\|contribute}). |
| `app.update.check` | Check the update manifest for a newer release; returns the state. |
| `app.update.dismiss` | Decline the offered update (hides the startup prompt for it); returns the state. |
| `app.update.install` | Download and install the offered update; returns the state. |
| `app.update.state` | Return the self-update state (installed version, offered release, progress). |
| `map.camera.get` | Return the current map camera. |
| `map.camera.set` | Move the map camera (params: lat, lon, zoom?, bearing?, tilt?). |
| `map.fitFriends` | Frame every friend who is sharing their location: fit them all, or centre one friend when only they are live. Returns how many were framed. |
| `map.follow` | Enable/disable location follow (params: {on}). |
| `map.followMyLocation` | Toggle following the device location (return the new state). |
| `map.friendMarkers` | List the live friend badges currently drawn on the map. |
| `map.location` | Return the live device-location state (last fix, whether a fix is being shown, and whether the device cannot be located — location services off or permission denied). |
| `map.markers.clear` | Remove all map markers. |
| `map.markers.get` | List the current map markers. |
| `map.markers.set` | Replace the map markers (params: {markers: [{id, lat, lon, selected?}]}). |
| `map.myLocation` | Move the camera to the last known location (zooms in), using the already-tracked fix when available so it is instant. |
| `map.orientation` | Set the map orientation while following the location (params: {mode: north\|heading}); omit "mode" to toggle between them. Returns the mode. |
| `map.resetBearing` | Reset the map bearing to north and lock north-up (keeping position and zoom), so a fix while following does not rotate it away. |
| `map.reviews` | List the review badges currently drawn on the map (one per reviewed place on screen). |
| `map.reviews.friendOnly` | Show only places a friend has reviewed on the map (params: {on?}); returns the new state. |
| `map.routeLines` | List the route polylines currently drawn on the map (colour, dashed, width and a bounded sample of points). |
| `map.style.get` | Return the current base map style name. |
| `map.style.set` | Switch the base map style (params: {style: standard\|satellite\|terrain}). |
| `map.traffic` | Toggle the traffic overlay (params: {on?}); returns the new state. |
| `map.transitStops` | List the transit stop circles drawn for the selected journey (small pass-through stops and larger boarding/alighting circles). |
| `nav.mode` | Change the travel mode of the running guidance session, re-skinning the navigation UI without touching the map (params: {mode: drive\|walk\|cycle\|transit}). |
| `nav.notification` | Return the ongoing trip notification (visible, title, body, progress 0–100, statusChip, mode) shown in the shade while navigating. |
| `nav.overview` | Toggle the navigation overview (fit the whole route) vs tracking. |
| `nav.pause` | Stop the camera tracking the position (guidance keeps running). |
| `nav.position` | Inject a position sample (params: {lat, lon, heading?, speed?}); speed is metres per second and drives the tracking-camera zoom. |
| `nav.resume` | Re-center the camera on the current position and resume tracking. |
| `nav.start` | Start simulated guidance (params: {index?, auto?}); requires a planned route. |
| `nav.state` | Return the current guidance state. |
| `nav.step` | Advance simulated guidance (params: {meters?, speed?}); speed is metres per second and drives the tracking-camera zoom. |
| `nav.stop` | Stop guidance. |
| `place.bookmark` | Save/remove a place (params: {id, bookmarked?}); returns the saved state. |
| `place.bookmarks` | List saved (bookmarked) places. |
| `place.call` | Open the dialler for a place phone number (params: {id?, phone?}; defaults to the selected place's OSM number). Returns the number and whether an app opened. |
| `place.clear` | Clear the selected place. |
| `place.clearHome` | Remove the saved Home place. |
| `place.clearWork` | Remove the saved Work place. |
| `place.copyAddress` | Copy a place address to the clipboard (params: {id?}; defaults to the selected place). |
| `place.details` | Details for a place (params: {id?}; defaults to the selected place), merged with its OpenStreetMap tags — contact phone/e-mail/website, wheelchair access, opening hours, accepted payments, images and the raw tags. |
| `place.email` | Compose an e-mail to a place (params: {id?, email?}; defaults to the selected place's OSM address). Returns the address and whether an app opened. |
| `place.nearby` | Browse places near a place (params: {id?}; defaults to the selected place). Opens the category results over the map. |
| `place.openWebsite` | Open a place website (params: {id?, website?}; defaults to the selected place's OSM site). Returns the URL and whether a browser opened. |
| `place.select` | Select a place by id; keeps the other result pins and highlights it (params: {id, focus?}). Set focus:false to leave the camera as-is. |
| `place.setHome` | Save a place as Home (params: {id?}; defaults to the selected place). |
| `place.setWork` | Save a place as Work (params: {id?}; defaults to the selected place). |
| `place.share` | Copy a share line for a place (params: {id?}; defaults to the selected place) — name, address and OpenStreetMap link where known. Returns the text. |
| `review.compose` | Open the "Write a review" sheet for a place (params: {id?}; defaults to the selected place). Returns the draft state. |
| `review.compose.close` | Close the "Write a review" sheet. |
| `review.copy` | Copy review text to the clipboard (params: {text}); returns the text. Used by the "Share review" action. |
| `review.draft.set` | Update the review draft (params: {rating?: 0..1, stars?: 1..5, text?, visibility?: public\|friends}). Returns the draft state. |
| `review.helpful` | Mark a review "Helpful" (params: {id, helpful?}); returns the new state. Session-local. |
| `review.list` | List the reviews for a place (params: {id?}; defaults to the selected place). Returns the summary with the average rating and friends. |
| `review.open` | Open the place sheet for a review badge (params: {placeKey?} or {id?}; focus?: default true moves the camera to it). An OSM element we do not already know is looked up so the sheet shows its real name. |
| `review.photo.add` | Attach a photo to the review draft (params: {path} for a local file, or {base64, mimeType?}; mimeType? also used with path). Returns the draft state. |
| `review.publish` | Publish the current review draft as a Nostr kind-31987 event (photos uploaded to Blossom, links appended to the content). Returns the draft state. |
| `review.simulate.add` | Demo/debug only: inject a synthetic review so the map badge and the place sheet can be driven without relays (params: {id? (place id), pubkey?, name?, rating?, text?, lat?, lon?, friend?}). Works only on the keyless fake backend. |
| `route.addStop` | Add a stop before the destination (params: {id}). |
| `route.clear` | Clear the current route. |
| `route.cycle` | Tune bicycle routing options and re-plan (params: {bicycle_type?: road\|hybrid\|cross\|mountain, use_hills?: 0..1, avoid_bad_surfaces?: 0..1, cycling_speed?: km/h, use_roads?: 0..1, avoid_edges?: bool}). Omitted options keep their current value. |
| `route.destination` | Set the route destination (params: {id}). |
| `route.editEndpoint` | Open the search-style place picker for a route endpoint (params: {field: origin\|destination\|stop, index?}). A "stop" with no index picks a new stop to append; with an index it edits that stop. |
| `route.endpoint.close` | Close the endpoint place picker. |
| `route.mode` | Change the travel mode (params: {mode: drive\|walk\|cycle}). |
| `route.origin` | Set the route start (params: {id}). |
| `route.pickOnMap` | Arm long-press picking (params: {field: origin\|destination\|stop, index?}). A "stop" with no index fills a new stop on the next long-press. |
| `route.plan` | Plan a route to a place id (params: {id}). |
| `route.removeStop` | Remove a route stop by index (params: {index}). |
| `route.request` | Request a street route (params: {origin:{lat,lon}, destination:{lat,lon}, mode?: drive\|walk\|cycle}). For public transport use `transit.plan`. |
| `route.select` | Select a route alternative by index (params: {index}). |
| `route.setStop` | Replace the route stop at an index (params: {index, id}). |
| `route.swap` | Swap the route start and destination. |
| `route.useCurrentLocation` | Set a route endpoint to the current location (params: {field: origin\|destination\|stop, index?}; default origin). |
| `search.categories` | List the browse categories grouped for the picker, marking the pinned ones (params: {}). |
| `search.category` | Browse a category near the user, keeping the map visible with the places pinned and a results sheet (params: {name: <label or id>}). Passing no {name} clears the browse. Returns the results. |
| `search.pin` | Pin a category chip to the row under the search bar (params: {name: <label or id>}). Up to 10 pins; returns {"pinned": <ids>, "added": <bool>}. |
| `search.query` | Run a search query (params: {text}) and return the results. |
| `search.recents` | List the recent searches — places and queries — newest first. |
| `search.recents.clear` | Clear the recent-search list. |
| `search.unpin` | Unpin a category chip from the row under the search bar (params: {name: <label or id>}); returns {"pinned": <ids>}. |
| `session.help` | Describe one command (params: {id}) or all of them. |
| `session.list` | List every command id and its description. |
| `social.followings` | List the people the signed-in user follows (NIP-02 contact list) with a flag for those already in the "friends" set. |
| `social.friend.add` | Add a public key to your "friends" set (params: {pubkey}). Writes a NIP-51 kind-30000 set named "friends". |
| `social.friend.remove` | Remove a public key from your "friends" set (params: {pubkey}). |
| `social.friend.select` | Open a friend's live-location sheet (params: {pubkey, focus?}) or clear it with no/invalid {pubkey}. focus (default true) moves the camera to them; pass focus:false when the pin is already on screen. |
| `social.friendLocations` | List the friends currently sharing their live location. |
| `social.friends` | List the signed-in user's friends (the NIP-51 "friends" set) with their live status; re-reads from the network. |
| `social.login` | Sign in to Nostr with a private key (params: {nsec}) so live location can be gift-wrap encrypted to friends. |
| `social.logout` | Sign out of Nostr and stop watching friend shares. |
| `social.share.start` | Start sharing live location (params: {recipients: [pubkey,…], "all", or "self" for a private preview; durationMinutes?}). Publishes the first gift-wrapped update and shows the ongoing notification. |
| `social.share.state` | Return the outgoing live-share state. |
| `social.share.stop` | Stop the active live-location share. |
| `social.simulate.friendLocation` | Demo/debug only: inject a synthetic friend live location (params: {pubkey?, lat?, lon?, minutes?}). Works only when the keyless fake backend is active. |
| `social.state` | Return the social state: Nostr identity, live friends, outgoing live-share status. |
| `transit.departures` | Open the departures board for a stop (params: {stopId, name?}). Returns the loaded departures. |
| `transit.departures.close` | Close the departures board. |
| `transit.detail` | Open the detail view (step 2) for a public-transport journey (params: {index?}; defaults to the selected). Returns the journey. |
| `transit.detail.close` | Return from the journey detail to the journey list. |
| `transit.itineraries` | List the public-transport journeys currently planned. |
| `transit.navigate` | Start guidance along the selected public-transport journey (the detail view's Start button). Returns the navigation state. |
| `transit.plan` | Plan a public-transport journey and show it in Transit mode (params: {origin:{lat,lon}, destination:{lat,lon}, stops?:[{lat,lon}], time? (ISO-8601), arriveBy?, modes?:[bus,tram,subway,train,ferry], fewerTransfers?, lessWalking?}). Returns the itineraries. |
| `transit.pref` | Set transit preferences (params: {modes?:[bus,tram,subway,train,ferry], fewerTransfers?, lessWalking?}); re-plans. Returns the itineraries. |
| `transit.select` | Select a public-transport journey by index (params: {index}). |
| `transit.stop.close` | Close the stop Departures tab and clear its map lines. |
| `transit.stop.earlier` | Load the departures before the earliest one shown for the open stop. |
| `transit.stop.later` | Load the departures after the latest one shown for the open stop. |
| `transit.stop.open` | Open the station sheet's Departures tab for a stop (params: {id?, name?, lat?, lon?}; uses the selected transit place when no coordinate is given). Draws the stop's lines on the map. Returns the board state. |
| `transit.stop.trip` | Open one train's detail (its whole stop list) and show only that line on the map (params: {tripId}). Returns the board state. |
| `transit.stop.trip.close` | Close the train detail and restore the stop's lines on the map. |
| `transit.time` | Set when the transit journey departs or arrives (params: {mode: now\|depart\|arrive, time? (ISO-8601)}); re-plans. |
| `ui.back` | Synthesise the system back gesture. |
| `ui.screenshot` | Capture the app window to a PNG file (params: path?). |
| `ui.scroll` | Synthesise a scroll gesture by (dx, dy) from (x, y) (params: {x, y, dx, dy}). |
| `ui.swipe` | Synthesise a drag (params: {fromX, fromY, toX, toY}). |
| `ui.tap` | Synthesise a tap at logical coordinates (params: {x, y}). |
<!-- END GENERATED COMMANDS -->
