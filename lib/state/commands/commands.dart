import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/errors/result.dart';
import '../../core/utils/osm_payments.dart';
import '../../core/utils/osm_ref.dart';
import '../../data/fakes/fake_review_service.dart';
import '../../data/fakes/fake_social_service.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/app_update.dart';
import '../../domain/entities/camera.dart';
import '../../domain/entities/cycling_options.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_location.dart';
import '../../domain/entities/friend_marker.dart';
import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/live_share.dart';
import '../../domain/entities/location_sample.dart';
import '../../domain/entities/map_style.dart';
import '../../domain/entities/marker.dart';
import '../../domain/entities/metric_event.dart';
import '../../domain/entities/place.dart';
import '../../domain/entities/place_category.dart';
import '../../domain/entities/recent_search.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/review_draft.dart';
import '../../domain/entities/review_marker.dart';
import '../../domain/entities/review_place.dart';
import '../../domain/entities/review_summary.dart';
import '../../domain/entities/route.dart';
import '../../domain/entities/route_line.dart';
import '../../domain/entities/transit.dart';
import '../../domain/entities/transit_stop_marker.dart';
import '../../domain/entities/travel_mode.dart';
import '../../domain/ports/app_database.dart';
import '../../domain/ports/map_service.dart';
import '../../domain/ports/settings_repository.dart';
import '../config.dart';
import '../follow.dart';
import '../home.dart';
import '../location.dart';
import '../map_layers.dart';
import '../navigation.dart';
import '../navigation_keys.dart';
import '../navigation_notifications.dart';
import '../place.dart';
import '../ports.dart';
import '../reviews.dart';
import '../route.dart';
import '../saved_places.dart';
import '../screenshot.dart';
import '../search.dart';
import '../settings.dart';
import '../social.dart';
import '../transit_departures.dart';
import '../update.dart';
import '../usecases.dart';
import 'command.dart';
import 'synthetic_input.dart';

/// Builds the M1 command set. Feature commands are added as their screens land
/// (M2+), always routing through the same notifiers/use cases the UI uses.
List<Command> buildCommands(Ref ref) {
  return <Command>[
    Command(
      id: 'app.ready',
      description: 'Return true once the app is running.',
      handler: (CommandRequest request) async => true,
    ),
    Command(
      id: 'app.state',
      description: 'Dump serialisable app state.',
      handler: (CommandRequest request) async {
        final AppConfig config = ref.read(appConfigProvider);
        return <String, Object?>{
          'ready': true,
          'buildMode': _buildMode(),
          'config': <String, Object?>{
            'hasMapboxToken': config.hasMapboxToken,
            'hasValhallaEndpoint': config.hasValhallaEndpoint,
            'hasCamelusToken': config.hasCamelusToken,
          },
          'camera': _cameraJson(ref.read(mapServiceProvider).camera),
          'style': ref.read(mapStyleProvider).name,
          'traffic': ref.read(trafficProvider),
          'followingLocation': ref.read(followModeProvider),
          'orientation': ref.read(mapOrientationProvider).name,
          'home': switch (ref.read(savedPlacesProvider).home) {
            final Place place => _placeJson(place),
            _ => null,
          },
          'work': switch (ref.read(savedPlacesProvider).work) {
            final Place place => _placeJson(place),
            _ => null,
          },
        };
      },
    ),
    Command(
      id: 'app.db',
      description:
          'Report the local database (schema version, open state, metric '
          'count, setting keys); optionally record a metric or clear the log '
          '(params: {record: {name, value?, labels?}, clearMetrics?}).',
      handler: (CommandRequest request) async {
        final AppDatabase database = ref.read(appDatabaseProvider);

        final Object? rawRecord = request.params['record'];
        if (rawRecord != null) {
          if (rawRecord is! Map<Object?, Object?>) {
            throw const CommandException(
              'bad_params',
              '"record" must be an object',
            );
          }
          final Object? name = rawRecord['name'];
          if (name is! String || name.trim().isEmpty) {
            throw const CommandException(
              'bad_params',
              '"record.name" must be a non-empty string',
            );
          }
          double? value;
          final Object? rawValue = rawRecord['value'];
          if (rawValue != null) {
            if (rawValue is! num) {
              throw const CommandException(
                'bad_params',
                '"record.value" must be a number',
              );
            }
            value = rawValue.toDouble();
          }
          final Map<String, String> labels = <String, String>{};
          final Object? rawLabels = rawRecord['labels'];
          if (rawLabels is Map<Object?, Object?>) {
            for (final MapEntry<Object?, Object?> entry in rawLabels.entries) {
              if (labels.length >= MetricEvent.maxLabels) {
                break;
              }
              final Object? key = entry.key;
              final Object? labelValue = entry.value;
              if (key is String && labelValue is String) {
                labels[key] = labelValue;
              }
            }
          }
          await database.recordMetric(
            MetricEvent.create(name, value: value, labels: labels),
          );
        }

        if (request.params['clearMetrics'] == true) {
          await database.clearMetrics();
        }

        final List<String> settingsKeys =
            (await database.readSettings()).keys
                .where((String key) => !key.startsWith('_'))
                .toList()
              ..sort();
        return <String, Object?>{
          'schemaVersion': database.schemaVersion,
          'storedSchemaVersion': await database.readStoredSchemaVersion(),
          'opened': database.isOpen,
          'metrics': await database.countMetrics(),
          'settingsKeys': settingsKeys,
        };
      },
    ),
    Command(
      id: 'app.tab',
      description: 'Select the map-home bottom-nav tab (params: {tab: explore|you|contribute}).',
      handler: (CommandRequest request) async {
        final HomeTab? tab = switch (request.params['tab']) {
          'explore' => HomeTab.explore,
          'you' => HomeTab.you,
          'contribute' => HomeTab.contribute,
          _ => null,
        };
        if (tab == null) {
          throw const CommandException(
            'bad_params',
            '"tab" must be explore|you|contribute',
          );
        }
        ref.read(homeTabProvider.notifier).select(tab);
        return tab.name;
      },
    ),
    Command(
      id: 'app.settings',
      description:
          'Return app settings (distance unit, theme, search provider, '
          'developer options).',
      handler: (CommandRequest request) async {
        final AppSettings settings = ref.read(settingsProvider);
        return <String, Object?>{
          'unit': settings.unit.name,
          'theme': settings.theme.name,
          'showOsmTags': settings.showOsmTags,
          'searchBackend': settings.searchBackend.name,
          'pinnedCategories': settings.pinnedCategoryIds,
        };
      },
    ),
    Command(
      id: 'app.settings.set',
      description:
          'Update app settings (params: {unit?: metric|imperial, theme?: '
          'system|light|dark, showOsmTags?: bool, searchBackend?: '
          'mapbox|openstreetmap|camelus}).',
      handler: (CommandRequest request) async {
        final Object? rawUnit = request.params['unit'];
        if (rawUnit != null) {
          final DistanceUnit? unit = switch (rawUnit) {
            'metric' => DistanceUnit.metric,
            'imperial' => DistanceUnit.imperial,
            _ => null,
          };
          if (unit == null) {
            throw const CommandException(
              'bad_params',
              '"unit" must be metric|imperial',
            );
          }
          await ref.read(settingsProvider.notifier).setUnit(unit);
        }
        final Object? rawTheme = request.params['theme'];
        if (rawTheme != null) {
          final AppThemeMode? theme = switch (rawTheme) {
            'system' => AppThemeMode.system,
            'light' => AppThemeMode.light,
            'dark' => AppThemeMode.dark,
            _ => null,
          };
          if (theme == null) {
            throw const CommandException(
              'bad_params',
              '"theme" must be system|light|dark',
            );
          }
          await ref.read(settingsProvider.notifier).setTheme(theme);
        }
        final Object? rawShowOsmTags = request.params['showOsmTags'];
        if (rawShowOsmTags != null) {
          if (rawShowOsmTags is! bool) {
            throw const CommandException(
              'bad_params',
              '"showOsmTags" must be a boolean',
            );
          }
          await ref
              .read(settingsProvider.notifier)
              .setShowOsmTags(rawShowOsmTags);
        }
        final Object? rawSearchBackend = request.params['searchBackend'];
        if (rawSearchBackend != null) {
          final SearchBackend? backend = switch (rawSearchBackend) {
            'mapbox' => SearchBackend.mapbox,
            'openstreetmap' || 'osm' => SearchBackend.openstreetmap,
            'camelus' => SearchBackend.camelus,
            _ => null,
          };
          if (backend == null) {
            throw const CommandException(
              'bad_params',
              '"searchBackend" must be mapbox|openstreetmap|camelus',
            );
          }
          await ref.read(settingsProvider.notifier).setSearchBackend(backend);
        }
        final AppSettings settings = ref.read(settingsProvider);
        return <String, Object?>{
          'unit': settings.unit.name,
          'theme': settings.theme.name,
          'showOsmTags': settings.showOsmTags,
          'searchBackend': settings.searchBackend.name,
          'pinnedCategories': settings.pinnedCategoryIds,
        };
      },
    ),
    Command(
      id: 'app.onboarding',
      description:
          'Get or set the onboarding-seen flag (params: {seen?}); returns it.',
      handler: (CommandRequest request) async {
        final SettingsRepository repository = ref.read(
          settingsRepositoryProvider,
        );
        final Object? raw = request.params['seen'];
        if (raw is bool) {
          await ref.read(setOnboardingSeenProvider)(raw);
        }
        return repository.onboardingSeen();
      },
    ),
    Command(
      id: 'app.update.state',
      description:
          'Return the self-update state (installed version, offered release, '
          'progress).',
      handler: (CommandRequest request) async =>
          _updateJson(ref.read(updateControllerProvider)),
    ),
    Command(
      id: 'app.update.check',
      description:
          'Check the update manifest for a newer release; returns the state.',
      handler: (CommandRequest request) async {
        await ref.read(updateControllerProvider.notifier).check();
        return _updateJson(ref.read(updateControllerProvider));
      },
    ),
    Command(
      id: 'app.update.dismiss',
      description:
          'Decline the offered update (hides the startup prompt for it); '
          'returns the state.',
      handler: (CommandRequest request) async {
        await ref.read(updateControllerProvider.notifier).dismissPrompt();
        return _updateJson(ref.read(updateControllerProvider));
      },
    ),
    Command(
      id: 'app.update.install',
      description:
          'Download and install the offered update; returns the state.',
      handler: (CommandRequest request) async {
        await ref.read(updateControllerProvider.notifier).install();
        return _updateJson(ref.read(updateControllerProvider));
      },
    ),
    Command(
      id: 'map.camera.get',
      description: 'Return the current map camera.',
      handler: (CommandRequest request) async =>
          _cameraJson(ref.read(mapServiceProvider).camera),
    ),
    Command(
      id: 'map.camera.set',
      description:
          'Move the map camera (params: lat, lon, zoom?, bearing?, tilt?).',
      handler: (CommandRequest request) async {
        final LatLon? target = LatLon.tryParse(
          request.params['lat'],
          request.params['lon'],
        );
        if (target == null) {
          throw const CommandException(
            'bad_params',
            'Valid "lat" and "lon" are required',
          );
        }
        final MapService service = ref.read(mapServiceProvider);
        ref.read(followModeProvider.notifier).disable();
        await service.moveCamera(
          Camera(
            target: target,
            zoom: _toDouble(request.params['zoom']) ?? service.camera.zoom,
            bearing: _toDouble(request.params['bearing']) ?? 0,
            tilt: _toDouble(request.params['tilt']) ?? 0,
          ),
        );
        return _cameraJson(service.camera);
      },
    ),
    Command(
      id: 'map.resetBearing',
      description:
          'Reset the map bearing to north and lock north-up (keeping position '
          'and zoom), so a fix while following does not rotate it away.',
      handler: (CommandRequest request) async {
        final MapService service = ref.read(mapServiceProvider);
        // Lock the orientation north too, so a fix while following does not
        // rotate the map away again.
        ref.read(mapOrientationProvider.notifier).select(MapOrientation.north);
        await service.moveCamera(service.camera.copyWith(bearing: 0));
        return _cameraJson(service.camera);
      },
    ),
    Command(
      id: 'map.orientation',
      description:
          'Set the map orientation while following the location '
          '(params: {mode: north|heading}); omit "mode" to toggle between them. '
          'Returns the mode.',
      handler: (CommandRequest request) async {
        final MapOrientationController controller = ref.read(
          mapOrientationProvider.notifier,
        );
        final Object? raw = request.params['mode'];
        switch (raw) {
          case null:
            controller.toggle();
          case 'north':
            controller.select(MapOrientation.north);
          case 'heading':
            controller.select(MapOrientation.heading);
          default:
            throw const CommandException(
              'bad_params',
              '"mode" must be "north" or "heading"',
            );
        }
        final MapOrientation mode = ref.read(mapOrientationProvider);
        // Apply now so the map turns immediately, not on the next fix.
        final MapService service = ref.read(mapServiceProvider);
        if (mode == MapOrientation.north) {
          await service.moveCamera(service.camera.copyWith(bearing: 0));
        } else if (ref.read(followModeProvider)) {
          final LocationSample? sample = await ref
              .read(locationServiceProvider)
              .lastKnown();
          final double? bearing = sample?.bearing;
          if (bearing != null) {
            await service.moveCamera(
              service.camera.copyWith(bearing: bearing),
              animated: true,
            );
          }
        }
        return mode.name;
      },
    ),
    Command(
      id: 'map.myLocation',
      description:
          'Move the camera to the last known location (zooms in), using the '
          'already-tracked fix when available so it is instant.',
      handler: (CommandRequest request) async {
        final LocationState tracked = ref.read(locationTrackerProvider);
        final LocationSample? sample =
            tracked.fix ?? await ref.read(locationServiceProvider).lastKnown();
        if (sample == null) {
          throw const CommandException('no_location', 'No last known location');
        }
        final MapService service = ref.read(mapServiceProvider);
        final Camera current = service.camera;
        await service.moveCamera(
          current.copyWith(
            target: sample.position,
            zoom: FollowController.locationZoom,
          ),
          animated: true,
        );
        return _cameraJson(service.camera);
      },
    ),
    Command(
      id: 'map.location',
      description:
          'Return the live device-location state (last fix, whether a fix is '
          'being shown, and whether the device cannot be located — location '
          'services off or permission denied).',
      handler: (CommandRequest request) async {
        final LocationState location = ref.read(locationTrackerProvider);
        final LocationSample? fix = location.fix;
        return <String, Object?>{
          'hasFix': location.hasFix,
          'streaming': location.streaming,
          'lost': location.lost,
          'lat': fix?.position.latitude,
          'lon': fix?.position.longitude,
          'bearing': fix?.bearing,
          'accuracy': fix?.accuracyMeters,
          'speed': fix?.speedMetersPerSecond,
        };
      },
    ),
    Command(
      id: 'map.markers.set',
      description:
          'Replace the map markers '
          '(params: {markers: [{id, lat, lon, selected?}]}).',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['markers'];
        if (raw is! List<Object?>) {
          throw const CommandException(
            'bad_params',
            '"markers" must be a list',
          );
        }
        final List<Marker> markers = <Marker>[];
        for (final Object? entry in raw) {
          if (entry is! Map<String, Object?>) {
            continue;
          }
          final LatLon? position = LatLon.tryParse(entry['lat'], entry['lon']);
          final Object? id = entry['id'];
          if (position == null || id is! String || id.isEmpty) {
            continue;
          }
          markers.add(
            Marker(
              id: id,
              position: position,
              selected: entry['selected'] == true,
            ),
          );
        }
        await ref.read(mapServiceProvider).setMarkers(markers);
        return <String, Object?>{'count': markers.length};
      },
    ),
    Command(
      id: 'map.markers.clear',
      description: 'Remove all map markers.',
      handler: (CommandRequest request) async {
        await ref.read(mapServiceProvider).setMarkers(const <Marker>[]);
        return <String, Object?>{'count': 0};
      },
    ),
    Command(
      id: 'map.markers.get',
      description: 'List the current map markers.',
      handler: (CommandRequest request) async => ref
          .read(mapServiceProvider)
          .markers
          .map(_markerJson)
          .toList(growable: false),
    ),
    Command(
      id: 'map.transitStops',
      description:
          'List the transit stop circles drawn for the selected journey '
          '(small pass-through stops and larger boarding/alighting circles).',
      handler: (CommandRequest request) async => ref
          .read(mapServiceProvider)
          .transitStopMarkers
          .map(_transitStopMarkerJson)
          .toList(growable: false),
    ),
    Command(
      id: 'map.routeLines',
      description:
          'List the route polylines currently drawn on the map (colour, dashed, '
          'width and a bounded sample of points).',
      handler: (CommandRequest request) async => ref
          .read(mapServiceProvider)
          .routeLines
          .map(_routeLineJson)
          .toList(growable: false),
    ),
    Command(
      id: 'search.query',
      description:
          'Run a search query (params: {text}) and return the results.',
      handler: (CommandRequest request) async {
        final Object? text = request.params['text'];
        if (text is! String || text.trim().isEmpty) {
          throw const CommandException('bad_params', '"text" is required');
        }
        await ref.read(searchControllerProvider.notifier).submit(text);
        return ref
            .read(searchControllerProvider)
            .results
            .map(_placeJson)
            .toList(growable: false);
      },
    ),
    Command(
      id: 'search.category',
      description:
          'Browse a category near the user, keeping the map visible with the '
          'places pinned and a results sheet (params: {name: <label or id>}). '
          'Passing no {name} clears the browse. Returns the results.',
      handler: (CommandRequest request) async {
        final Object? rawName = request.params['name'];
        if (rawName == null) {
          ref.read(selectedCategoryProvider.notifier).select(null);
          ref.read(searchControllerProvider.notifier).reset();
          return null;
        }
        final PlaceCategory category = _categoryFrom(rawName);
        // The map-local results sheet is the category browse surface (chips and
        // the direct "cafes"/"coffee" search both land here).
        await ref
            .read(searchControllerProvider.notifier)
            .browseCategory(category);
        final SearchState search = ref.read(searchControllerProvider);
        final AppException? error = search.error;
        if (error != null) {
          // Surface the typed failure (e.g. a provider with no category index)
          // to the caller instead of a silent empty list.
          throw CommandException('search_failed', error.message);
        }
        return search.results.map(_placeJson).toList(growable: false);
      },
    ),
    Command(
      id: 'search.categories',
      description:
          'List the browse categories grouped for the picker, marking the '
          'pinned ones (params: {}).',
      handler: (CommandRequest request) async {
        final Set<String> pinned = ref
            .read(settingsProvider)
            .pinnedCategoryIds
            .toSet();
        return <Object?>[
          for (final String group in categoryGroups)
            <String, Object?>{
              'group': group,
              'categories': <Object?>[
                for (final PlaceCategory category in placeCategories)
                  if (category.group == group)
                    <String, Object?>{
                      'id': category.id,
                      'label': category.label,
                      'pinned': pinned.contains(category.id),
                    },
              ],
            },
        ];
      },
    ),
    Command(
      id: 'search.pin',
      description:
          'Pin a category chip to the row under the search bar (params: '
          '{name: <label or id>}). Up to $maxPinnedCategories pins; returns '
          '{"pinned": <ids>, "added": <bool>}.',
      handler: (CommandRequest request) async {
        final PlaceCategory category = _categoryFrom(request.params['name']);
        final bool added = await ref
            .read(settingsProvider.notifier)
            .pinCategory(category.id);
        return <String, Object?>{
          'pinned': ref.read(settingsProvider).pinnedCategoryIds,
          'added': added,
        };
      },
    ),
    Command(
      id: 'search.unpin',
      description:
          'Unpin a category chip from the row under the search bar (params: '
          '{name: <label or id>}); returns {"pinned": <ids>}.',
      handler: (CommandRequest request) async {
        final PlaceCategory category = _categoryFrom(request.params['name']);
        await ref.read(settingsProvider.notifier).unpinCategory(category.id);
        return <String, Object?>{
          'pinned': ref.read(settingsProvider).pinnedCategoryIds,
        };
      },
    ),
    Command(
      id: 'search.recents',
      description:
          'List the recent searches — places and queries — newest first.',
      handler: (CommandRequest request) async => <Object?>[
        for (final RecentSearch entry in ref.read(recentSearchesProvider))
          _recentSearchJson(entry),
      ],
    ),
    Command(
      id: 'search.recents.clear',
      description: 'Clear the recent-search list.',
      handler: (CommandRequest request) async {
        await ref.read(recentSearchesProvider.notifier).clear();
        return true;
      },
    ),
    Command(
      id: 'place.setHome',
      description:
          'Save a place as Home (params: {id?}; defaults to the selected '
          'place).',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request, enrich: false);
        if (place == null) {
          throw const CommandException(
            'bad_params',
            'pass an "id" or select a place first',
          );
        }
        await ref.read(savedPlacesProvider.notifier).setHome(place);
        return _placeJson(place);
      },
    ),
    Command(
      id: 'place.clearHome',
      description: 'Remove the saved Home place.',
      handler: (CommandRequest request) async {
        await ref.read(savedPlacesProvider.notifier).setHome(null);
        return true;
      },
    ),
    Command(
      id: 'place.setWork',
      description:
          'Save a place as Work (params: {id?}; defaults to the selected '
          'place).',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request, enrich: false);
        if (place == null) {
          throw const CommandException(
            'bad_params',
            'pass an "id" or select a place first',
          );
        }
        await ref.read(savedPlacesProvider.notifier).setWork(place);
        return _placeJson(place);
      },
    ),
    Command(
      id: 'place.clearWork',
      description: 'Remove the saved Work place.',
      handler: (CommandRequest request) async {
        await ref.read(savedPlacesProvider.notifier).setWork(null);
        return true;
      },
    ),
    Command(
      id: 'place.select',
      description:
          'Select a place by id; keeps the other result pins and highlights it '
          '(params: {id, focus?}). Set focus:false to leave the camera as-is.',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final bool focus = request.params['focus'] != false;
        Place? found;
        for (final Place candidate
            in ref.read(searchControllerProvider).results) {
          if (candidate.id == id) {
            found = candidate;
            break;
          }
        }
        found ??= await ref.read(placesRepositoryProvider).placeById(id);
        final Place? place = found;
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        ref.read(selectedPlaceProvider.notifier).select(place);
        ref.read(followModeProvider.notifier).disable();
        final MapService map = ref.read(mapServiceProvider);
        await map.setMarkers(_withSelected(map.markers, place));
        if (focus) {
          await map.moveCamera(
            map.camera.copyWith(target: place.position, zoom: 15),
          );
        }
        return _placeJson(place);
      },
    ),
    Command(
      id: 'place.clear',
      description: 'Clear the selected place.',
      handler: (CommandRequest request) async {
        ref.read(selectedPlaceProvider.notifier).clear();
        final MapService map = ref.read(mapServiceProvider);
        await map.setMarkers(_clearedSelection(map.markers));
        return true;
      },
    ),
    Command(
      id: 'place.nearby',
      description:
          'Browse places near a place (params: {id?}; defaults to the selected '
          'place). Opens the category results over the map.',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        Place? found;
        if (id is String && id.isNotEmpty) {
          for (final Place candidate
              in ref.read(searchControllerProvider).results) {
            if (candidate.id == id) {
              found = candidate;
              break;
            }
          }
          found ??= await ref.read(placesRepositoryProvider).placeById(id);
        } else {
          found = ref.read(selectedPlaceProvider);
        }
        final Place? place = found;
        if (place == null) {
          throw const CommandException(
            'bad_params',
            'pass an "id" or select a place first',
          );
        }
        final PlaceCategory? category = placeCategoryFromText(place.category);
        final String label = category?.label ?? 'Nearby';
        // The category sheet replaces the place sheet, so drop the selection.
        ref.read(selectedPlaceProvider.notifier).clear();
        ref.read(selectedCategoryProvider.notifier).select(label);
        await ref
            .read(searchControllerProvider.notifier)
            .browseNear(
              place.position,
              label: label,
              category: category,
              text: place.category ?? place.name,
            );
        return ref
            .read(searchControllerProvider)
            .results
            .map(_placeJson)
            .toList(growable: false);
      },
    ),
    Command(
      id: 'route.request',
      description:
          'Request a street route (params: {origin:{lat,lon}, destination:{lat,lon}, '
          'mode?: drive|walk|cycle}). For public transport use `transit.plan`.',
      handler: (CommandRequest request) async {
        final LatLon? origin = _pointFrom(request.params['origin']);
        final LatLon? destination = _pointFrom(request.params['destination']);
        if (origin == null || destination == null) {
          throw const CommandException(
            'bad_params',
            'origin and destination {lat,lon} are required',
          );
        }
        final TravelMode mode = _travelMode(request.params['mode']);
        if (mode.isTransit) {
          throw const CommandException(
            'bad_params',
            'use `transit.plan` (or `route.mode` with "transit") for public transport',
          );
        }
        final Result<List<Route>> result = await ref.read(requestRouteProvider)(
          waypoints: <LatLon>[origin, destination],
          mode: mode,
          cycling: mode == TravelMode.cycle
              ? ref.read(routeControllerProvider).cycling
              : null,
        );
        if (result.isErr) {
          throw result.errorOrNull ?? const UnknownException('Routing failed');
        }
        final List<Route> routes = result.valueOrNull ?? const <Route>[];
        return routes.map(_routeJson).toList(growable: false);
      },
    ),
    Command(
      id: 'route.plan',
      description: 'Plan a route to a place id (params: {id}).',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        Place? place;
        for (final Place candidate
            in ref.read(searchControllerProvider).results) {
          if (candidate.id == id) {
            place = candidate;
            break;
          }
        }
        place ??= await ref.read(placesRepositoryProvider).placeById(id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        await ref.read(routeControllerProvider.notifier).plan(place);
        final Route? selected = ref.read(routeControllerProvider).selectedRoute;
        return selected == null ? null : _routeJson(selected);
      },
    ),
    Command(
      id: 'route.mode',
      description: 'Change the travel mode (params: {mode: drive|walk|cycle}).',
      handler: (CommandRequest request) async {
        final TravelMode mode = _travelMode(request.params['mode']);
        await ref.read(routeControllerProvider.notifier).setMode(mode);
        return mode.name;
      },
    ),
    Command(
      id: 'route.cycle',
      description:
          'Tune bicycle routing options and re-plan (params: '
          '{bicycle_type?: road|hybrid|cross|mountain, use_hills?: 0..1, '
          'avoid_bad_surfaces?: 0..1, cycling_speed?: km/h, use_roads?: 0..1, '
          'avoid_edges?: bool}). Omitted options keep their current value.',
      handler: (CommandRequest request) async {
        final CyclingOptions current = ref
            .read(routeControllerProvider)
            .cycling;
        final bool hasType = request.params.containsKey('bicycle_type');
        final double? speed = _finite(request.params['cycling_speed']);
        final CyclingOptions next = current.copyWith(
          bicycleType: hasType
              ? BicycleType.parse(request.params['bicycle_type'])
              : null,
          useHills: _finite(request.params['use_hills']),
          avoidBadSurfaces: _finite(request.params['avoid_bad_surfaces']),
          cyclingSpeed: speed,
          // Changing the bike drops an explicit speed so the new type's default
          // applies, unless a speed was given in the same call.
          clearCyclingSpeed: hasType && speed == null,
          useRoads: _finite(request.params['use_roads']),
          avoidEdges: request.params['avoid_edges'] is bool
              ? request.params['avoid_edges'] as bool
              : null,
        );
        await ref
            .read(routeControllerProvider.notifier)
            .setCyclingOptions(next);
        return next.toJson();
      },
    ),
    Command(
      id: 'route.select',
      description: 'Select a route alternative by index (params: {index}).',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['index'];
        final int? index = switch (raw) {
          final int value => value,
          final double value => value.toInt(),
          final String value => int.tryParse(value),
          _ => null,
        };
        if (index == null) {
          throw const CommandException('bad_params', '"index" is required');
        }
        ref.read(routeControllerProvider.notifier).selectRoute(index);
        return index;
      },
    ),
    Command(
      id: 'route.clear',
      description: 'Clear the current route.',
      handler: (CommandRequest request) async {
        ref.read(routeControllerProvider.notifier).clear();
        return true;
      },
    ),
    Command(
      id: 'route.origin',
      description: 'Set the route start (params: {id}).',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final Place? place = await _findPlace(ref, id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        await ref.read(routeControllerProvider.notifier).setOrigin(place);
        final Route? selected = ref.read(routeControllerProvider).selectedRoute;
        return selected == null ? null : _routeJson(selected);
      },
    ),
    Command(
      id: 'route.destination',
      description: 'Set the route destination (params: {id}).',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final Place? place = await _findPlace(ref, id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        await ref.read(routeControllerProvider.notifier).setDestination(place);
        final Route? selected = ref.read(routeControllerProvider).selectedRoute;
        return selected == null ? null : _routeJson(selected);
      },
    ),
    Command(
      id: 'route.addStop',
      description: 'Add a stop before the destination (params: {id}).',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final Place? place = await _findPlace(ref, id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        await ref.read(routeControllerProvider.notifier).addStop(place);
        return true;
      },
    ),
    Command(
      id: 'route.removeStop',
      description: 'Remove a route stop by index (params: {index}).',
      handler: (CommandRequest request) async {
        final Object? index = request.params['index'];
        if (index is! int || index < 0) {
          throw const CommandException(
            'bad_params',
            '"index" must be a non-negative integer',
          );
        }
        final RouteState current = ref.read(routeControllerProvider);
        if (index >= current.stops.length) {
          throw const CommandException('bad_params', 'stop index out of range');
        }
        await ref.read(routeControllerProvider.notifier).removeStopAt(index);
        return true;
      },
    ),
    Command(
      id: 'route.swap',
      description: 'Swap the route start and destination.',
      handler: (CommandRequest request) async {
        ref.read(routeControllerProvider.notifier).swap();
        return true;
      },
    ),
    Command(
      id: 'route.pickOnMap',
      description:
          'Arm long-press picking (params: {field: origin|destination|stop, '
          'index?}). A "stop" with no index fills a new stop on the next '
          'long-press.',
      handler: (CommandRequest request) async {
        ref
            .read(routeControllerProvider.notifier)
            .beginPick(
              _endpointTargetFrom(
                request.params['field'],
                request.params['index'],
                defaultField: RouteEndpointField.origin,
              ),
            );
        return true;
      },
    ),
    Command(
      id: 'route.editEndpoint',
      description:
          'Open the search-style place picker for a route endpoint '
          '(params: {field: origin|destination|stop, index?}). A "stop" with no '
          'index picks a new stop to append; with an index it edits that stop.',
      handler: (CommandRequest request) async {
        final RouteEndpointTarget target = _endpointTargetFrom(
          request.params['field'],
          request.params['index'],
        );
        ref.read(routeControllerProvider.notifier).openEndpointPicker(target);
        unawaited(
          rootNavigatorKey.currentContext?.push('/directions/endpoint'),
        );
        return _endpointTargetJson(target);
      },
    ),
    Command(
      id: 'route.endpoint.close',
      description: 'Close the endpoint place picker.',
      handler: (CommandRequest request) async {
        ref.read(routeControllerProvider.notifier).closeEndpointPicker();
        final BuildContext? context = rootNavigatorKey.currentContext;
        if (context != null && context.canPop()) {
          context.pop();
        }
        return true;
      },
    ),
    Command(
      id: 'route.useCurrentLocation',
      description:
          'Set a route endpoint to the current location '
          '(params: {field: origin|destination|stop, index?}; default origin).',
      handler: (CommandRequest request) async {
        final RouteEndpointTarget target = _endpointTargetFrom(
          request.params['field'],
          request.params['index'],
          defaultField: RouteEndpointField.origin,
        );
        await ref
            .read(routeControllerProvider.notifier)
            .useCurrentLocationFor(target);
        final Route? selected = ref.read(routeControllerProvider).selectedRoute;
        return selected == null ? null : _routeJson(selected);
      },
    ),
    Command(
      id: 'route.setStop',
      description: 'Replace the route stop at an index (params: {index, id}).',
      handler: (CommandRequest request) async {
        final Object? index = request.params['index'];
        final Object? id = request.params['id'];
        if (index is! int || index < 0) {
          throw const CommandException(
            'bad_params',
            '"index" must be a non-negative integer',
          );
        }
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        if (index >= ref.read(routeControllerProvider).stops.length) {
          throw const CommandException('bad_params', 'stop index out of range');
        }
        final Place? place = await _findPlace(ref, id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        await ref.read(routeControllerProvider.notifier).setStop(index, place);
        final Route? selected = ref.read(routeControllerProvider).selectedRoute;
        return selected == null ? null : _routeJson(selected);
      },
    ),
    Command(
      id: 'transit.plan',
      description:
          'Plan a public-transport journey and show it in Transit mode '
          '(params: {origin:{lat,lon}, destination:{lat,lon}, stops?:[{lat,lon}], '
          'time? (ISO-8601), arriveBy?, modes?:[bus,tram,subway,train,ferry], '
          'fewerTransfers?, lessWalking?}). Returns the itineraries.',
      handler: (CommandRequest request) async {
        final LatLon? origin = _pointFrom(request.params['origin']);
        final LatLon? destination = _pointFrom(request.params['destination']);
        if (origin == null || destination == null) {
          throw const CommandException(
            'bad_params',
            'origin and destination {lat,lon} are required',
          );
        }
        final Set<TransitMode> modes = _transitModesFrom(
          request.params['modes'],
        );
        await ref
            .read(routeControllerProvider.notifier)
            .planTransit(
              origin: _transitPlace(
                'origin',
                origin,
                name: _nameFrom(request.params['origin']) ?? 'Origin',
              ),
              destination: _transitPlace(
                'destination',
                destination,
                name: _nameFrom(request.params['destination']) ?? 'Destination',
              ),
              stops: _transitStops(request.params['stops']),
              timeMode: request.params['arriveBy'] == true
                  ? TransitTimeMode.arriveBy
                  : (request.params['time'] != null
                        ? TransitTimeMode.departAt
                        : TransitTimeMode.leaveNow),
              time: _timeFrom(request.params['time']),
              preferredModes: modes,
              fewerTransfers: request.params['fewerTransfers'] == true,
              lessWalking: request.params['lessWalking'] == true,
            );
        return _transitResult(ref);
      },
    ),
    Command(
      id: 'transit.itineraries',
      description: 'List the public-transport journeys currently planned.',
      handler: (CommandRequest request) async => ref
          .read(routeControllerProvider)
          .itineraries
          .map(_itineraryJson)
          .toList(growable: false),
    ),
    Command(
      id: 'transit.select',
      description:
          'Select a public-transport journey by index (params: {index}).',
      handler: (CommandRequest request) async {
        final int? index = _intFrom(request.params['index']);
        if (index == null) {
          throw const CommandException('bad_params', '"index" is required');
        }
        final RouteState current = ref.read(routeControllerProvider);
        if (index < 0 || index >= current.itineraries.length) {
          throw const CommandException(
            'bad_params',
            'journey index out of range',
          );
        }
        ref.read(routeControllerProvider.notifier).selectItinerary(index);
        return _itineraryJson(current.itineraries[index]);
      },
    ),
    Command(
      id: 'transit.time',
      description:
          'Set when the transit journey departs or arrives '
          '(params: {mode: now|depart|arrive, time? (ISO-8601)}); re-plans.',
      handler: (CommandRequest request) async {
        final TransitTimeMode? timeMode = switch (request.params['mode']) {
          'now' || 'leaveNow' => TransitTimeMode.leaveNow,
          'depart' || 'departAt' => TransitTimeMode.departAt,
          'arrive' || 'arriveBy' => TransitTimeMode.arriveBy,
          _ => null,
        };
        if (timeMode == null) {
          throw const CommandException(
            'bad_params',
            '"mode" must be now|depart|arrive',
          );
        }
        final RouteController controller = ref.read(
          routeControllerProvider.notifier,
        );
        await controller.setTransitTimeMode(timeMode);
        final DateTime? time = _timeFrom(request.params['time']);
        if (time != null) {
          await controller.setTransitTime(time);
        }
        return _transitResult(ref);
      },
    ),
    Command(
      id: 'transit.pref',
      description:
          'Set transit preferences (params: {modes?:[bus,tram,subway,train,ferry], '
          'fewerTransfers?, lessWalking?}); re-plans. Returns the itineraries.',
      handler: (CommandRequest request) async {
        final Object? rawModes = request.params['modes'];
        final Object? rawFewer = request.params['fewerTransfers'];
        final Object? rawLess = request.params['lessWalking'];
        if (rawModes == null && rawFewer == null && rawLess == null) {
          throw const CommandException(
            'bad_params',
            'pass "modes", "fewerTransfers" or "lessWalking"',
          );
        }
        await ref
            .read(routeControllerProvider.notifier)
            .setTransitPreferences(
              modes: rawModes == null ? null : _transitModesFrom(rawModes),
              fewerTransfers: rawFewer is bool ? rawFewer : null,
              lessWalking: rawLess is bool ? rawLess : null,
            );
        return _transitResult(ref);
      },
    ),
    Command(
      id: 'transit.detail',
      description:
          'Open the detail view (step 2) for a public-transport journey '
          '(params: {index?}; defaults to the selected). Returns the journey.',
      handler: (CommandRequest request) async {
        final RouteState state = ref.read(routeControllerProvider);
        final int index =
            _intFrom(request.params['index']) ?? state.selectedItineraryIndex;
        if (index < 0 || index >= state.itineraries.length) {
          throw const CommandException(
            'bad_params',
            'journey index out of range',
          );
        }
        ref.read(routeControllerProvider.notifier).openTransitDetail(index);
        return _itineraryJson(state.itineraries[index]);
      },
    ),
    Command(
      id: 'transit.detail.close',
      description: 'Return from the journey detail to the journey list.',
      handler: (CommandRequest request) async {
        ref.read(routeControllerProvider.notifier).closeTransitDetail();
        return true;
      },
    ),
    Command(
      id: 'transit.departures',
      description:
          'Open the departures board for a stop (params: {stopId, name?}). '
          'Returns the loaded departures.',
      handler: (CommandRequest request) async {
        final Object? rawId = request.params['stopId'];
        final String? stopId = rawId is String ? rawId.trim() : null;
        if (stopId == null || stopId.isEmpty) {
          throw const CommandException('bad_params', '"stopId" is required');
        }
        final Object? rawName = request.params['name'];
        await ref
            .read(transitDeparturesProvider.notifier)
            .open(stopId: stopId, stopName: rawName is String ? rawName : null);
        return _departuresJson(ref.read(transitDeparturesProvider));
      },
    ),
    Command(
      id: 'transit.departures.close',
      description: 'Close the departures board.',
      handler: (CommandRequest request) async {
        ref.read(transitDeparturesProvider.notifier).close();
        return true;
      },
    ),
    Command(
      id: 'transit.navigate',
      description:
          'Start guidance along the selected public-transport journey (the '
          'detail view\'s Start button). Returns the navigation state.',
      handler: (CommandRequest request) async {
        final TransitItinerary? itinerary = ref
            .read(routeControllerProvider)
            .selectedItinerary;
        if (itinerary == null) {
          throw const CommandException(
            'no_journey',
            'Select a public-transport journey first',
          );
        }
        final Route route = itinerary.toRoute();
        if (route.geometry.length < 2) {
          throw const CommandException(
            'no_route',
            'This journey has no geometry to follow',
          );
        }
        ref
            .read(navigationControllerProvider.notifier)
            .start(
              route,
              mode: TravelMode.transit,
              transit: itinerary,
              // Transit guidance follows the live GNSS stream (the map tracks
              // the traveller and boarding is detected from the position);
              // pass `live:false` for a purely simulated run.
              live: request.params['live'] != false,
            );
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.start',
      description: 'Start simulated guidance (params: {index?, auto?}); requires a planned route.',
      handler: (CommandRequest request) async {
        final RouteState routeState = ref.read(routeControllerProvider);
        final Object? rawIndex = request.params['index'];
        if (rawIndex is int &&
            rawIndex >= 0 &&
            rawIndex < routeState.routes.length) {
          ref.read(routeControllerProvider.notifier).selectRoute(rawIndex);
        }
        final Route? route = ref.read(routeControllerProvider).selectedRoute;
        if (route == null) {
          throw const CommandException('no_route', 'Plan a route first');
        }
        ref
            .read(navigationControllerProvider.notifier)
            .start(
              route,
              auto: request.params['auto'] == true,
              live: request.params['live'] == true,
              mode: ref.read(routeControllerProvider).mode,
            );
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.position',
      description:
          'Inject a position sample (params: {lat, lon, heading?, speed?}); '
          'speed is metres per second and drives the tracking-camera zoom.',
      handler: (CommandRequest request) async {
        final LatLon? point = LatLon.tryParse(
          request.params['lat'],
          request.params['lon'],
        );
        if (point == null) {
          throw const CommandException('bad_params', 'lat/lon are required');
        }
        await ref
            .read(navigationControllerProvider.notifier)
            .handlePosition(
              LocationSample(
                position: point,
                bearing: _toDouble(request.params['heading']),
                speedMetersPerSecond: _toDouble(request.params['speed']),
              ),
            );
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.step',
      description:
          'Advance simulated guidance (params: {meters?, speed?}); speed is '
          'metres per second and drives the tracking-camera zoom.',
      handler: (CommandRequest request) async {
        ref
            .read(navigationControllerProvider.notifier)
            .step(
              meters: _toDouble(request.params['meters']) ?? 40,
              speedMetersPerSecond: _toDouble(request.params['speed']),
            );
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.state',
      description: 'Return the current guidance state.',
      handler: (CommandRequest request) async =>
          _navJson(ref.read(navigationControllerProvider)),
    ),
    Command(
      id: 'nav.notification',
      description:
          'Return the ongoing trip notification (visible, title, body, '
          'progress 0–100, statusChip, mode) shown in the shade while '
          'navigating.',
      handler: (CommandRequest request) async {
        final NavigationNotice notice = ref.read(navigationNoticeProvider);
        return <String, Object?>{
          'visible': notice.visible,
          'title': notice.title,
          'body': notice.body,
          'progress': notice.progress,
          'statusChip': notice.statusChip,
          'mode': notice.mode.name,
        };
      },
    ),
    Command(
      id: 'nav.stop',
      description: 'Stop guidance.',
      handler: (CommandRequest request) async {
        ref.read(navigationControllerProvider.notifier).stop();
        return true;
      },
    ),
    Command(
      id: 'nav.overview',
      description:
          'Toggle the navigation overview (fit the whole route) vs tracking.',
      handler: (CommandRequest request) async {
        ref.read(navigationControllerProvider.notifier).toggleOverview();
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.mode',
      description:
          'Change the travel mode of the running guidance session, re-skinning '
          'the navigation UI without touching the map (params: {mode: '
          'drive|walk|cycle|transit}).',
      handler: (CommandRequest request) async {
        final TravelMode mode = _travelMode(request.params['mode']);
        ref.read(navigationControllerProvider.notifier).setMode(mode);
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.pause',
      description:
          'Stop the camera tracking the position (guidance keeps running).',
      handler: (CommandRequest request) async {
        ref.read(navigationControllerProvider.notifier).pauseTracking();
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'nav.resume',
      description:
          'Re-center the camera on the current position and resume tracking.',
      handler: (CommandRequest request) async {
        ref.read(navigationControllerProvider.notifier).resumeTracking();
        return _navJson(ref.read(navigationControllerProvider));
      },
    ),
    Command(
      id: 'map.followMyLocation',
      description:
          'Toggle following the device location (return the new state).',
      handler: (CommandRequest request) async {
        await ref.read(followModeProvider.notifier).toggle();
        return ref.read(followModeProvider);
      },
    ),
    Command(
      id: 'map.follow',
      description: 'Enable/disable location follow (params: {on}).',
      handler: (CommandRequest request) async {
        final FollowController controller = ref.read(
          followModeProvider.notifier,
        );
        if (request.params['on'] == false) {
          controller.disable();
        } else {
          await controller.enable();
        }
        return ref.read(followModeProvider);
      },
    ),
    Command(
      id: 'map.style.set',
      description: 'Switch the base map style (params: {style: standard|satellite|terrain}).',
      handler: (CommandRequest request) async {
        final BaseMapStyle style = _baseMapStyle(request.params['style']);
        await ref.read(mapStyleProvider.notifier).select(style);
        return style.name;
      },
    ),
    Command(
      id: 'map.style.get',
      description: 'Return the current base map style name.',
      handler: (CommandRequest request) async =>
          ref.read(mapStyleProvider).name,
    ),
    Command(
      id: 'map.traffic',
      description:
          'Toggle the traffic overlay (params: {on?}); returns the new state.',
      handler: (CommandRequest request) async {
        final TrafficController controller = ref.read(trafficProvider.notifier);
        final Object? on = request.params['on'];
        if (on == null) {
          await controller.toggle();
        } else {
          await controller.set(on == true);
        }
        return ref.read(trafficProvider);
      },
    ),
    Command(
      id: 'place.bookmarks',
      description: 'List saved (bookmarked) places.',
      handler: (CommandRequest request) async {
        final List<Place> saved = await ref
            .read(placesRepositoryProvider)
            .bookmarks();
        return saved.map(_placeJson).toList(growable: false);
      },
    ),
    Command(
      id: 'place.bookmark',
      description: 'Save/remove a place (params: {id, bookmarked?}); returns the saved state.',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final Place? place = await _findPlace(ref, id);
        if (place == null) {
          throw NotFoundException('Place not found: $id');
        }
        final bool bookmarked = request.params['bookmarked'] != false;
        await ref.read(toggleBookmarkProvider)(place, bookmarked: bookmarked);
        await ref.read(savedMarkersProvider.notifier).refresh();
        return bookmarked;
      },
    ),
    Command(
      id: 'place.copyAddress',
      description: 'Copy a place address to the clipboard (params: {id?}; defaults to the selected place).',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        Place? place;
        if (id is String && id.isNotEmpty) {
          place = await _findPlace(ref, id);
        }
        place ??= ref.read(selectedPlaceProvider);
        if (place == null) {
          throw const CommandException('no_place', 'No place selected');
        }
        final String address = place.address ?? place.name;
        try {
          await Clipboard.setData(ClipboardData(text: address));
        } catch (_) {
          // Clipboard is best-effort (and unavailable in plain unit tests);
          // the address is still returned to the caller.
        }
        return <String, Object?>{'id': place.id, 'address': address};
      },
    ),
    Command(
      id: 'place.details',
      description:
          'Details for a place (params: {id?}; defaults to the selected place), '
          'merged with its OpenStreetMap tags — contact phone/e-mail/website, '
          'wheelchair access, opening hours, accepted payments, images and the '
          'raw tags.',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request);
        if (place == null) {
          throw const CommandException(
            'no_place',
            'pass an "id" or select a place first',
          );
        }
        return _placeJson(place);
      },
    ),
    Command(
      id: 'place.call',
      description:
          'Open the dialler for a place phone number (params: {id?, phone?}; '
          'defaults to the selected place\'s OSM number). Returns the number and '
          'whether an app opened.',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request);
        final String? phone = _stringParam(request, 'phone') ?? place?.phone;
        if (phone == null) {
          throw const CommandException(
            'no_contact',
            'No phone number for this place',
          );
        }
        final bool launched = await ref
            .read(externalActionsProvider)
            .call(phone);
        return <String, Object?>{'phone': phone, 'launched': launched};
      },
    ),
    Command(
      id: 'place.email',
      description:
          'Compose an e-mail to a place (params: {id?, email?}; defaults to the '
          'selected place\'s OSM address). Returns the address and whether an app '
          'opened.',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request);
        final String? address = _stringParam(request, 'email') ?? place?.email;
        if (address == null) {
          throw const CommandException(
            'no_contact',
            'No e-mail address for this place',
          );
        }
        final bool launched = await ref
            .read(externalActionsProvider)
            .email(address);
        return <String, Object?>{'email': address, 'launched': launched};
      },
    ),
    Command(
      id: 'place.openWebsite',
      description:
          'Open a place website (params: {id?, website?}; defaults to the '
          'selected place\'s OSM site). Returns the URL and whether a browser '
          'opened.',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request);
        final String? url = _stringParam(request, 'website') ?? place?.website;
        if (url == null) {
          throw const CommandException(
            'no_contact',
            'No website for this place',
          );
        }
        final bool launched = await ref
            .read(externalActionsProvider)
            .openWebsite(url);
        return <String, Object?>{'website': url, 'launched': launched};
      },
    ),
    Command(
      id: 'place.share',
      description:
          'Copy a share line for a place (params: {id?}; defaults to the '
          'selected place) — name, address and OpenStreetMap link where known. '
          'Returns the text.',
      handler: (CommandRequest request) async {
        final Place? place = await _resolvePlace(ref, request);
        if (place == null) {
          throw const CommandException(
            'no_place',
            'pass an "id" or select a place first',
          );
        }
        final String text = _shareText(place);
        try {
          await Clipboard.setData(ClipboardData(text: text));
        } catch (_) {
          // Clipboard is best-effort (and unavailable in plain unit tests).
        }
        return <String, Object?>{'id': place.id, 'text': text};
      },
    ),
    Command(
      id: 'social.state',
      description:
          'Return the social state: Nostr identity, live friends, outgoing '
          'live-share status.',
      handler: (CommandRequest request) async => <String, Object?>{
        'signedIn': ref.read(socialServiceProvider).isLoggedIn,
        'pubkey': ref.read(socialServiceProvider).currentUserPubkey,
        'selectedFriend': ref.read(selectedFriendProvider),
        'friendsLive': ref
            .read(friendLocationsProvider)
            .map((FriendLocation location) => location.pubkey)
            .toList(growable: false),
        'share': _liveShareJson(ref.read(liveShareProvider)),
      },
    ),
    Command(
      id: 'social.login',
      description:
          'Sign in to Nostr with a private key (params: {nsec}) so live location '
          'can be gift-wrap encrypted to friends.',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['nsec'];
        if (raw is! String || raw.trim().isEmpty) {
          throw const CommandException('bad_params', '"nsec" is required');
        }
        await ref.read(socialServiceProvider).signInWithPrivateKey(raw);
        ref.invalidate(friendsProvider);
        return <String, Object?>{
          'signedIn': ref.read(socialServiceProvider).isLoggedIn,
          'pubkey': ref.read(socialServiceProvider).currentUserPubkey,
        };
      },
    ),
    Command(
      id: 'social.logout',
      description: 'Sign out of Nostr and stop watching friend shares.',
      handler: (CommandRequest request) async {
        await ref.read(liveShareProvider.notifier).stop();
        await ref.read(socialServiceProvider).logout();
        ref.read(selectedFriendProvider.notifier).clear();
        ref.invalidate(friendsProvider);
        return true;
      },
    ),
    Command(
      id: 'social.friends',
      description:
          'List the signed-in user\'s friends (the NIP-51 "friends" set) with '
          'their live status; re-reads from the network.',
      handler: (CommandRequest request) async {
        ref.invalidate(friendsProvider);
        final List<Friend> friends = await ref.read(friendsProvider.future);
        final Map<String, FriendLocation> live = <String, FriendLocation>{
          for (final FriendLocation location in ref.read(
            friendLocationsProvider,
          ))
            location.pubkey: location,
        };
        return <Map<String, Object?>>[
          for (final Friend friend in friends)
            _friendJson(friend, live[friend.pubkey]),
        ];
      },
    ),
    Command(
      id: 'social.friend.select',
      description:
          'Open a friend\'s live-location sheet (params: {pubkey, focus?}) or '
          'clear it with no/invalid {pubkey}. focus (default true) moves the '
          'camera to them; pass focus:false when the pin is already on screen.',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['pubkey'];
        final String? pubkey = raw is String && raw.trim().isNotEmpty
            ? raw.trim()
            : null;
        if (pubkey == null) {
          ref.read(selectedFriendProvider.notifier).clear();
          return null;
        }
        ref.read(selectedPlaceProvider.notifier).clear();
        ref.read(selectedFriendProvider.notifier).select(pubkey);
        if (request.params['focus'] != false) {
          await _focusFriend(ref, pubkey);
        }
        return pubkey;
      },
    ),
    Command(
      id: 'map.fitFriends',
      description:
          'Frame every friend who is sharing their location: fit them all, or '
          'centre one friend when only they are live. Returns how many were '
          'framed.',
      handler: (CommandRequest request) async {
        final List<LatLon> points = _liveFriendPoints(ref);
        if (points.isEmpty) {
          throw const CommandException(
            'no_friends',
            'No friend is sharing their location right now',
          );
        }
        ref.read(followModeProvider.notifier).disable();
        final MapService map = ref.read(mapServiceProvider);
        if (points.length == 1) {
          await map.moveCamera(
            map.camera.copyWith(target: points.first, zoom: 16),
            animated: true,
          );
        } else {
          await map.fitCoordinates(points);
        }
        return points.length;
      },
    ),
    Command(
      id: 'social.share.start',
      description:
          'Start sharing live location (params: {recipients: [pubkey,…], '
          '"all", or "self" for a private preview; durationMinutes?}). '
          'Publishes the first gift-wrapped update and shows the ongoing '
          'notification.',
      handler: (CommandRequest request) async {
        final List<Friend> friends = await ref.read(friendsProvider.future);
        final List<String> recipients = _recipientsFrom(
          request.params['recipients'],
          friends,
          ref,
        );
        if (recipients.isEmpty) {
          throw const CommandException(
            'bad_params',
            'provide {recipients: [pubkey,…]} or "all"',
          );
        }
        final Object? rawMinutes = request.params['durationMinutes'];
        final int? minutes = switch (rawMinutes) {
          final int value => value,
          final double value => value.toInt(),
          final String value => int.tryParse(value),
          _ => null,
        };
        if (minutes != null && (minutes < 1 || minutes > 720)) {
          throw const CommandException(
            'bad_params',
            '"durationMinutes" must be between 1 and 720',
          );
        }
        await ref
            .read(liveShareProvider.notifier)
            .start(
              recipients: recipients,
              duration: minutes == null
                  ? defaultLiveShareDuration
                  : Duration(minutes: minutes),
            );
        return _liveShareJson(ref.read(liveShareProvider));
      },
    ),
    Command(
      id: 'social.share.stop',
      description: 'Stop the active live-location share.',
      handler: (CommandRequest request) async {
        await ref.read(liveShareProvider.notifier).stop();
        return _liveShareJson(ref.read(liveShareProvider));
      },
    ),
    Command(
      id: 'social.share.state',
      description: 'Return the outgoing live-share state.',
      handler: (CommandRequest request) async =>
          _liveShareJson(ref.read(liveShareProvider)),
    ),
    Command(
      id: 'social.friendLocations',
      description: 'List the friends currently sharing their live location.',
      handler: (CommandRequest request) async => ref
          .read(friendLocationsProvider)
          .map(_friendLocationJson)
          .toList(growable: false),
    ),
    Command(
      id: 'social.friend.add',
      description:
          'Add a public key to your "friends" set (params: {pubkey}). Writes a '
          'NIP-51 kind-30000 set named "friends".',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['pubkey'];
        if (raw is! String || raw.trim().isEmpty) {
          throw const CommandException('bad_params', '"pubkey" is required');
        }
        await ref.read(socialServiceProvider).addFriend(raw);
        ref.invalidate(friendsProvider);
        final List<Friend> friends = await ref.read(friendsProvider.future);
        return friends.any(
          (Friend friend) => friend.pubkey == raw.trim().toLowerCase(),
        );
      },
    ),
    Command(
      id: 'social.friend.remove',
      description:
          'Remove a public key from your "friends" set (params: {pubkey}).',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['pubkey'];
        if (raw is! String || raw.trim().isEmpty) {
          throw const CommandException('bad_params', '"pubkey" is required');
        }
        await ref.read(socialServiceProvider).removeFriend(raw);
        ref.invalidate(friendsProvider);
        return true;
      },
    ),
    Command(
      id: 'social.followings',
      description:
          'List the people the signed-in user follows (NIP-02 contact list) '
          'with a flag for those already in the "friends" set.',
      handler: (CommandRequest request) async {
        final List<Friend> followings = await ref
            .read(socialServiceProvider)
            .loadFollowings();
        final Set<String> friends = <String>{
          for (final Friend friend
              in ref.read(friendsProvider).value ?? const <Friend>[])
            friend.pubkey,
        };
        return <Map<String, Object?>>[
          for (final Friend friend in followings)
            <String, Object?>{
              'pubkey': friend.pubkey,
              'name': friend.label,
              'friend': friends.contains(friend.pubkey),
            },
        ];
      },
    ),
    Command(
      id: 'map.friendMarkers',
      description: 'List the live friend badges currently drawn on the map.',
      handler: (CommandRequest request) async => ref
          .read(friendMarkersProvider)
          .map(
            (FriendMarker marker) => <String, Object?>{
              'pubkey': marker.pubkey,
              'label': marker.label,
              'lat': marker.position.latitude,
              'lon': marker.position.longitude,
            },
          )
          .toList(growable: false),
    ),
    Command(
      id: 'social.simulate.friendLocation',
      description:
          'Demo/debug only: inject a synthetic friend live location '
          '(params: {pubkey?, lat?, lon?, minutes?}). Works only when the '
          'keyless fake backend is active.',
      handler: (CommandRequest request) async {
        final FakeSocialService? demo = ref.read(demoSocialServiceProvider);
        if (demo == null) {
          throw const CommandException(
            'unsupported',
            'Simulating a friend is only available on the keyless fake backend',
          );
        }
        final List<Friend> friends = await ref.read(friendsProvider.future);
        if (friends.isEmpty) {
          throw const CommandException('no_friends', 'No friends to simulate');
        }
        final Object? rawPubkey = request.params['pubkey'];
        Friend friend = friends.first;
        if (rawPubkey is String && rawPubkey.trim().isNotEmpty) {
          for (final Friend candidate in friends) {
            if (candidate.pubkey == rawPubkey.trim()) {
              friend = candidate;
              break;
            }
          }
        }
        final LatLon point =
            LatLon.tryParse(request.params['lat'], request.params['lon']) ??
            ref.read(mapServiceProvider).camera.target;
        // Ensure the friend-location stream is being listened to before the
        // synthetic share is pushed, so an agent sees it immediately.
        ref.read(friendLocationsProvider);
        ref.read(friendMarkersProvider);
        final Object? rawMinutes = request.params['minutes'];
        final int minutes = switch (rawMinutes) {
          final int value => value,
          final double value => value.toInt(),
          final String value => int.tryParse(value) ?? 30,
          _ => 30,
        };
        final FriendLocation location = demo.seedLiveFriend(
          friend: friend,
          near: point,
          now: DateTime.now(),
          duration: Duration(minutes: minutes.clamp(1, 720)),
          index: friends.indexOf(friend),
        );
        return _friendLocationJson(location);
      },
    ),
    Command(
      id: 'review.compose',
      description:
          'Open the "Write a review" sheet for a place (params: {id?}; defaults '
          'to the selected place). Returns the draft state.',
      handler: (CommandRequest request) async {
        final Object? rawId = request.params['id'];
        Place? place;
        if (rawId is String && rawId.isNotEmpty) {
          place = await _findPlace(ref, rawId);
        }
        place ??= ref.read(selectedPlaceProvider);
        if (place == null) {
          throw const CommandException(
            'bad_params',
            'pass an "id" or select a place first',
          );
        }
        ref
            .read(reviewComposerProvider.notifier)
            .open(place, initial: _draftFromSummary(ref, place));
        return _reviewComposerJson(ref.read(reviewComposerProvider));
      },
    ),
    Command(
      id: 'review.compose.close',
      description: 'Close the "Write a review" sheet.',
      handler: (CommandRequest request) async {
        ref.read(reviewComposerProvider.notifier).close();
        return true;
      },
    ),
    Command(
      id: 'review.draft.set',
      description:
          'Update the review draft (params: {rating?: 0..1, stars?: 1..5, '
          'text?, visibility?: public|friends}). Returns the draft state.',
      handler: (CommandRequest request) async {
        final ReviewComposerController composer = ref.read(
          reviewComposerProvider.notifier,
        );
        final Object? rawStars = request.params['stars'];
        final int? stars = switch (rawStars) {
          final int value => value,
          final double value => value.toInt(),
          final String value => int.tryParse(value),
          _ => null,
        };
        if (stars != null) {
          composer.setStars(stars);
        }
        final Object? rawRating = request.params['rating'];
        final double? rating = _toDouble(rawRating);
        if (rating != null) {
          composer.setRating(rating);
        }
        final Object? rawText = request.params['text'];
        if (rawText is String) {
          composer.setText(rawText);
        }
        final Object? rawVisibility = request.params['visibility'];
        if (rawVisibility != null) {
          final ReviewVisibility? visibility = switch (rawVisibility) {
            'public' => ReviewVisibility.public,
            'friends' => ReviewVisibility.friends,
            _ => null,
          };
          if (visibility == null) {
            throw const CommandException(
              'bad_params',
              '"visibility" must be public|friends',
            );
          }
          composer.setVisibility(visibility);
        }
        return _reviewComposerJson(ref.read(reviewComposerProvider));
      },
    ),
    Command(
      id: 'review.photo.add',
      description:
          'Attach a photo to the review draft (params: {path} for a local file, '
          'or {base64, mimeType?}; mimeType? also used with path). Returns '
          'the draft state.',
      handler: (CommandRequest request) async {
        final ReviewComposerState composer = ref.read(reviewComposerProvider);
        if (!composer.isOpen) {
          throw const CommandException(
            'no_draft',
            'Open the composer first (review.compose)',
          );
        }
        final Object? rawPath = request.params['path'];
        final Object? rawBase64 = request.params['base64'];
        Uint8List? data;
        if (rawPath is String && rawPath.trim().isNotEmpty) {
          try {
            data = await File(rawPath.trim()).readAsBytes();
          } on FileSystemException catch (error) {
            throw CommandException(
              'io_error',
              'Could not read "$rawPath": ${error.message}',
            );
          }
        } else if (rawBase64 is String && rawBase64.isNotEmpty) {
          try {
            data = base64Decode(rawBase64);
          } on FormatException {
            throw const CommandException(
              'bad_params',
              '"base64" is not valid base64',
            );
          }
        }
        if (data == null || data.isEmpty) {
          throw const CommandException(
            'bad_params',
            'pass a "path" or "base64"',
          );
        }
        final Object? rawMime = request.params['mimeType'];
        ref.read(reviewComposerProvider.notifier).addPhotos(<ReviewPhoto>[
          ReviewPhoto(
            data: data,
            mimeType: rawMime is String && rawMime.isNotEmpty ? rawMime : null,
          ),
        ]);
        return _reviewComposerJson(ref.read(reviewComposerProvider));
      },
    ),
    Command(
      id: 'review.publish',
      description:
          'Publish the current review draft as a Nostr kind-31987 event '
          '(photos uploaded to Blossom, links appended to the content). '
          'Returns the draft state.',
      handler: (CommandRequest request) async {
        await ref.read(reviewComposerProvider.notifier).publish();
        final ReviewComposerState state = ref.read(reviewComposerProvider);
        if (state.error != null) {
          throw CommandException('publish_failed', state.error!);
        }
        return _reviewComposerJson(state);
      },
    ),
    Command(
      id: 'review.list',
      description:
          'List the reviews for a place (params: {id?}; defaults to the selected '
          'place). Returns the summary with the average rating and friends.',
      handler: (CommandRequest request) async {
        final String placeKey = await _placeKeyForRequest(ref, request);
        await ref.read(placeReviewsProvider(placeKey).future);
        return _reviewSummaryJson(
          ref.read(placeReviewSummaryProvider(placeKey)),
        );
      },
    ),
    Command(
      id: 'review.open',
      description:
          'Open the place sheet for a review badge (params: {placeKey?} or '
          '{id?}; focus?: default true moves the camera to it). An OSM element '
          'we do not already know is looked up so the sheet shows its real name.',
      handler: (CommandRequest request) async {
        final Object? rawKey = request.params['placeKey'];
        final Object? rawId = request.params['id'];
        String placeKey;
        if (rawKey is String && rawKey.trim().isNotEmpty) {
          placeKey = rawKey.trim();
        } else if (rawId is String && rawId.trim().isNotEmpty) {
          placeKey = ReviewPlace.keyFor(rawId.trim());
        } else {
          throw const CommandException(
            'bad_params',
            'pass a "placeKey" or an "id"',
          );
        }
        final String id = ReviewPlace.idFromKey(placeKey);
        Place? place = await _findPlace(ref, id);
        place ??= await _lookupOsmPlace(ref, id);
        place ??= Place(
          id: id,
          name: _fallbackPlaceName(id),
          position: _positionForPlaceKey(ref, placeKey),
        );
        ref.read(selectedFriendProvider.notifier).clear();
        ref.read(selectedPlaceProvider.notifier).select(place);
        if (request.params['focus'] != false) {
          ref.read(followModeProvider.notifier).disable();
          final MapService map = ref.read(mapServiceProvider);
          await map.moveCamera(
            map.camera.copyWith(target: place.position, zoom: 15),
          );
        }
        return _placeJson(place);
      },
    ),
    Command(
      id: 'map.reviews',
      description:
          'List the review badges currently drawn on the map (one per reviewed '
          'place on screen).',
      handler: (CommandRequest request) async => ref
          .read(reviewMarkersProvider)
          .map(_reviewMarkerJson)
          .toList(growable: false),
    ),
    Command(
      id: 'map.reviews.friendOnly',
      description:
          'Show only places a friend has reviewed on the map '
          '(params: {on?}); returns the new state.',
      handler: (CommandRequest request) async {
        final FriendReviewsOnlyController controller = ref.read(
          friendReviewsOnlyProvider.notifier,
        );
        final Object? on = request.params['on'];
        final bool value = on == null
            ? !ref.read(friendReviewsOnlyProvider)
            : on == true;
        controller.set(value);
        ref.read(reviewMarkersProvider.notifier).setFriendOnly(value);
        return value;
      },
    ),
    Command(
      id: 'review.helpful',
      description:
          'Mark a review "Helpful" (params: {id, helpful?}); returns the new '
          'state. Session-local.',
      handler: (CommandRequest request) async {
        final Object? id = request.params['id'];
        if (id is! String || id.isEmpty) {
          throw const CommandException('bad_params', '"id" is required');
        }
        final HelpfulReviewsController controller = ref.read(
          helpfulReviewsProvider.notifier,
        );
        final Object? helpful = request.params['helpful'];
        if (helpful is bool) {
          return controller.set(id, helpful);
        }
        return controller.toggle(id);
      },
    ),
    Command(
      id: 'review.copy',
      description:
          'Copy review text to the clipboard (params: {text}); returns the '
          'text. Used by the "Share review" action.',
      handler: (CommandRequest request) async {
        final Object? raw = request.params['text'];
        if (raw is! String || raw.trim().isEmpty) {
          throw const CommandException('bad_params', '"text" is required');
        }
        final String text = raw.length > 4000 ? raw.substring(0, 4000) : raw;
        try {
          await Clipboard.setData(ClipboardData(text: text));
        } catch (_) {
          // Clipboard is best-effort (and unavailable in plain unit tests).
        }
        return text;
      },
    ),
    Command(
      id: 'review.simulate.add',
      description:
          'Demo/debug only: inject a synthetic review so the map badge and the '
          'place sheet can be driven without relays (params: {id? (place id), '
          'pubkey?, name?, rating?, text?, lat?, lon?, friend?}). Works only on '
          'the keyless fake backend.',
      handler: (CommandRequest request) async {
        final FakeReviewService? demo = ref.read(demoReviewServiceProvider);
        if (demo == null) {
          throw const CommandException(
            'unsupported',
            'Simulating a review is only available on the keyless fake backend',
          );
        }
        final Object? rawId = request.params['id'];
        Place? place;
        if (rawId is String && rawId.isNotEmpty) {
          place = await _findPlace(ref, rawId);
        }
        place ??= ref.read(selectedPlaceProvider);
        final LatLon position =
            LatLon.tryParse(request.params['lat'], request.params['lon']) ??
            place?.position ??
            ref.read(mapServiceProvider).camera.target;
        final Object? rawPubkey = request.params['pubkey'];
        final String pubkey = rawPubkey is String && rawPubkey.length == 64
            ? rawPubkey.toLowerCase()
            : request.params['friend'] == true
            ? FakeSocialService.demoFriends.first.pubkey
            : '9000000000000000000000000000000000000000000000000000000000000099';
        final double rating =
            _toDouble(request.params['rating']) ??
            (request.params['friend'] == true ? 1.0 : 0.8);
        final Object? rawText = request.params['text'];
        final String text = rawText is String && rawText.trim().isNotEmpty
            ? rawText.trim()
            : 'A lovely spot — worth a detour.';
        final Object? rawName = request.params['name'];
        final Review review = Review(
          id: 'sim-${DateTime.now().microsecondsSinceEpoch}',
          authorPubkey: pubkey,
          placeKey: ReviewPlace.keyFor(place?.id ?? 'simulated'),
          rating: rating.clamp(0.0, 1.0),
          content: text,
          position: position,
          createdAt: DateTime.now().toUtc(),
          authorName: rawName is String && rawName.isNotEmpty ? rawName : null,
        );
        demo.seed(review);
        ref.invalidate(placeReviewsProvider(review.placeKey));
        await ref.read(reviewMarkersProvider.notifier).refresh();
        return _reviewJson(review);
      },
    ),
    Command(
      id: 'ui.tap',
      description: 'Synthesise a tap at logical coordinates (params: {x, y}).',
      handler: (CommandRequest request) async {
        final double? x = _finite(request.params['x']);
        final double? y = _finite(request.params['y']);
        if (x == null || y == null) {
          throw const CommandException(
            'bad_params',
            '"x" and "y" are required',
          );
        }
        SyntheticInput.tap(x, y);
        return true;
      },
    ),
    Command(
      id: 'ui.swipe',
      description: 'Synthesise a drag (params: {fromX, fromY, toX, toY}).',
      handler: (CommandRequest request) async {
        final double? fromX = _finite(request.params['fromX']);
        final double? fromY = _finite(request.params['fromY']);
        final double? toX = _finite(request.params['toX']);
        final double? toY = _finite(request.params['toY']);
        if (fromX == null || fromY == null || toX == null || toY == null) {
          throw const CommandException(
            'bad_params',
            '"fromX", "fromY", "toX" and "toY" are required',
          );
        }
        SyntheticInput.swipe(fromX: fromX, fromY: fromY, toX: toX, toY: toY);
        return true;
      },
    ),
    Command(
      id: 'ui.scroll',
      description:
          'Synthesise a scroll gesture by (dx, dy) from (x, y) '
          '(params: {x, y, dx, dy}).',
      handler: (CommandRequest request) async {
        final double? x = _finite(request.params['x']);
        final double? y = _finite(request.params['y']);
        final double? dx = _finite(request.params['dx']);
        final double? dy = _finite(request.params['dy']);
        if (x == null || y == null || dx == null || dy == null) {
          throw const CommandException(
            'bad_params',
            '"x", "y", "dx" and "dy" are required',
          );
        }
        SyntheticInput.swipe(fromX: x, fromY: y, toX: x - dx, toY: y - dy);
        return true;
      },
    ),
    Command(
      id: 'ui.back',
      description: 'Synthesise the system back gesture.',
      handler: (CommandRequest request) async {
        final BuildContext? context = rootNavigatorKey.currentContext;
        if (context == null) {
          return false;
        }
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
        return true;
      },
    ),
    Command(
      id: 'ui.screenshot',
      description: 'Capture the app window to a PNG file (params: path?).',
      handler: (CommandRequest request) async {
        final Object? rawPath = request.params['path'];
        final String path = rawPath is String && rawPath.trim().isNotEmpty
            ? rawPath.trim()
            : '${Directory.systemTemp.path}/openmaps-screenshot.png';
        final Uint8List bytes = await captureRootPng();
        final File file = File(path);
        try {
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
        } on FileSystemException catch (error) {
          throw CommandException(
            'io_error',
            'Could not write screenshot to "$path": ${error.message}',
          );
        }
        return <String, Object?>{'path': file.path, 'bytes': bytes.length};
      },
    ),
  ];
}

String _buildMode() {
  if (kReleaseMode) {
    return 'release';
  }
  if (kProfileMode) {
    return 'profile';
  }
  return 'debug';
}

Map<String, Object?> _cameraJson(Camera camera) => <String, Object?>{
  'lat': camera.target.latitude,
  'lon': camera.target.longitude,
  'zoom': camera.zoom,
  'bearing': camera.bearing,
  'tilt': camera.tilt,
};

Map<String, Object?> _markerJson(Marker marker) => <String, Object?>{
  'id': marker.id,
  'lat': marker.position.latitude,
  'lon': marker.position.longitude,
  'selected': marker.selected,
};

Map<String, Object?> _transitStopMarkerJson(TransitStopMarker marker) =>
    <String, Object?>{
      'id': marker.id,
      'lat': marker.position.latitude,
      'lon': marker.position.longitude,
      'emphasis': marker.emphasis.name,
      'board': marker.isBoard,
    };

/// A bounded summary of a drawn [RouteLine] (a full polyline can be thousands
/// of points; the first/last plus the count is enough to verify a redraw).
Map<String, Object?> _routeLineJson(RouteLine line) {
  final List<LatLon> points = line.points;
  final LatLon? first = points.isEmpty ? null : points.first;
  final LatLon? last = points.isEmpty ? null : points.last;
  return <String, Object?>{
    'color': line.color,
    'dashed': line.dashed,
    'width': line.width,
    'primary': line.primary,
    'pointCount': points.length,
    'first': first == null
        ? null
        : <String, Object?>{'lat': first.latitude, 'lon': first.longitude},
    'last': last == null
        ? null
        : <String, Object?>{'lat': last.latitude, 'lon': last.longitude},
  };
}

/// Flags [place] as the selected marker in [current], keeping every other pin.
/// Adds the place when it is not already on the map.
List<Marker> _withSelected(List<Marker> current, Place place) {
  bool found = false;
  final List<Marker> result = <Marker>[];
  for (final Marker marker in current) {
    final bool selected = marker.id == place.id;
    found = found || selected;
    result.add(
      Marker(id: marker.id, position: marker.position, selected: selected),
    );
  }
  if (!found) {
    result.add(Marker(id: place.id, position: place.position, selected: true));
  }
  return result;
}

/// Drops the selection flag from every marker (on `place.clear`).
List<Marker> _clearedSelection(List<Marker> current) => <Marker>[
  for (final Marker marker in current)
    Marker(id: marker.id, position: marker.position),
];

/// Resolves a category from a command param that may be a label ("Cafes") or
/// an id ("cafe").
PlaceCategory _categoryFrom(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    throw const CommandException(
      'bad_params',
      '"name" must be a category label or id',
    );
  }
  final String value = raw.trim();
  final PlaceCategory? category =
      placeCategoryById(value) ?? placeCategoryByLabel(value);
  if (category == null) {
    throw CommandException('bad_params', 'Unknown category: $value');
  }
  return category;
}

Map<String, Object?> _placeJson(Place place) => <String, Object?>{
  'id': place.id,
  'name': place.name,
  'lat': place.position.latitude,
  'lon': place.position.longitude,
  if (place.category != null) 'category': place.category,
  if (place.address != null) 'address': place.address,
  if (place.email != null) 'email': place.email,
  if (place.phone != null) 'phone': place.phone,
  if (place.website != null) 'website': place.website,
  if (place.wheelchairAccessible != null)
    'wheelchairAccessible': place.wheelchairAccessible,
  if (place.openingHours != null) 'openingHours': place.openingHours,
  if (place.osmTags.isNotEmpty) 'osmTags': place.osmTags,
  if (place.imageUrls.isNotEmpty) 'images': place.imageUrls,
  if (place.paymentMethods.isNotEmpty)
    'payments': <String, Object?>{
      for (final OsmPaymentMethod method in place.paymentMethods)
        method.suffix: method.value,
    },
};

Map<String, Object?> _recentSearchJson(RecentSearch entry) => switch (entry) {
  RecentPlaceSearch(:final Place place) => <String, Object?>{
    'type': 'place',
    'place': _placeJson(place),
  },
  RecentTextSearch(:final String text) => <String, Object?>{
    'type': 'query',
    'text': text,
  },
};

Map<String, Object?> _friendJson(Friend friend, FriendLocation? live) {
  final LatLon? position = live?.position;
  return <String, Object?>{
    'pubkey': friend.pubkey,
    'name': friend.label,
    'live': live != null,
    if (live != null && position != null) ...<String, Object?>{
      'lat': position.latitude,
      'lon': position.longitude,
      'updatedAt': live.updatedAt.toIso8601String(),
      'expiresAt': live.expiresAt.toIso8601String(),
    },
  };
}

Map<String, Object?> _friendLocationJson(FriendLocation location) {
  final LatLon? position = location.position;
  return <String, Object?>{
    'pubkey': location.pubkey,
    'name': location.label,
    'ended': location.ended,
    'updatedAt': location.updatedAt.toIso8601String(),
    'expiresAt': location.expiresAt.toIso8601String(),
    if (position != null) ...<String, Object?>{
      'lat': position.latitude,
      'lon': position.longitude,
    },
  };
}

Map<String, Object?> _liveShareJson(LiveShareState share) => <String, Object?>{
  'status': share.status.name,
  'recipients': share.recipients,
  'recipientCount': share.recipientCount,
  'startedAt': share.startedAt?.toIso8601String(),
  'expiresAt': share.expiresAt?.toIso8601String(),
  'lastPublishedAt': share.lastPublishedAt?.toIso8601String(),
  'error': share.error,
};

/// The positions of every friend currently sharing their location.
List<LatLon> _liveFriendPoints(Ref ref) => <LatLon>[
  for (final FriendLocation location in ref.read(friendLocationsProvider))
    if (location.position != null && location.isLiveAt(DateTime.now()))
      location.position!,
];

/// Moves the camera to [pubkey]'s live position (used when a friend is picked
/// from the friends list), leaving follow mode off so the camera stays put.
Future<void> _focusFriend(Ref ref, String pubkey) async {
  for (final FriendLocation location in ref.read(friendLocationsProvider)) {
    final LatLon? position = location.position;
    if (location.pubkey != pubkey || position == null) {
      continue;
    }
    ref.read(followModeProvider.notifier).disable();
    final MapService map = ref.read(mapServiceProvider);
    await map.moveCamera(
      map.camera.copyWith(target: position, zoom: 16),
      animated: true,
    );
    return;
  }
}

/// Resolves the `recipients` param of `social.share.start`: either the literal
/// `"all"`, or a list of public keys. Unknown keys are dropped.
List<String> _recipientsFrom(Object? raw, List<Friend> friends, Ref ref) {
  if (raw == 'all') {
    return friends
        .map((Friend friend) => friend.pubkey)
        .toList(growable: false);
  }
  if (raw == 'self') {
    // A private preview addressed only to yourself: real relays, real
    // encryption, nothing sent to another person.
    final String? me = ref.read(socialServiceProvider).currentUserPubkey;
    return me == null ? const <String>[] : <String>[me];
  }
  if (raw is! List<Object?>) {
    return const <String>[];
  }
  final Set<String> known = <String>{
    for (final Friend friend in friends) friend.pubkey,
  };
  final List<String> recipients = <String>[];
  for (final Object? entry in raw) {
    if (entry is String && known.contains(entry.trim())) {
      final String pubkey = entry.trim();
      if (!recipients.contains(pubkey)) {
        recipients.add(pubkey);
      }
    }
  }
  return recipients;
}

Map<String, Object?> _routeJson(Route route) => <String, Object?>{
  'distanceMeters': route.distanceMeters,
  'durationSeconds': route.duration.inSeconds,
  'geometryPoints': route.geometry.length,
  'steps': <Map<String, Object?>>[
    for (final Leg leg in route.legs)
      for (final Maneuver maneuver in leg.maneuvers)
        <String, Object?>{
          'instruction': maneuver.instruction,
          'type': maneuver.type.name,
          'distanceMeters': maneuver.distanceMeters,
        },
  ],
};

LatLon? _pointFrom(Object? raw) {
  if (raw is! Map<String, Object?>) {
    return null;
  }
  return LatLon.tryParse(raw['lat'], raw['lon']);
}

/// Parses an endpoint `field` (origin|destination|stop) plus an optional stop
/// `index` into a [RouteEndpointTarget]. When [field] is missing, [defaultField]
/// is used (origin for the long-press picker); an unknown non-null field is an
/// error.
RouteEndpointTarget _endpointTargetFrom(
  Object? field,
  Object? index, {
  RouteEndpointField? defaultField,
}) {
  if (field == null) {
    if (defaultField == null) {
      throw const CommandException(
        'bad_params',
        '"field" must be origin|destination|stop',
      );
    }
    return defaultField == RouteEndpointField.stop
        ? RouteEndpointTarget.stop(_intFrom(index))
        : defaultField == RouteEndpointField.destination
        ? const RouteEndpointTarget.destination()
        : const RouteEndpointTarget.origin();
  }
  if (field is! String) {
    throw const CommandException(
      'bad_params',
      '"field" must be origin|destination|stop',
    );
  }
  return switch (field) {
    'origin' => const RouteEndpointTarget.origin(),
    'destination' => const RouteEndpointTarget.destination(),
    'stop' => RouteEndpointTarget.stop(_intFrom(index)),
    _ => throw const CommandException(
      'bad_params',
      '"field" must be origin|destination|stop',
    ),
  };
}

Map<String, Object?> _endpointTargetJson(RouteEndpointTarget target) =>
    <String, Object?>{
      'field': target.field.name,
      if (target.stopIndex != null) 'index': target.stopIndex,
    };

TravelMode _travelMode(Object? raw) => switch (raw) {
  'walk' || 'pedestrian' => TravelMode.walk,
  'cycle' || 'bicycle' => TravelMode.cycle,
  'transit' || 'bus' || 'train' => TravelMode.transit,
  _ => TravelMode.drive,
};

BaseMapStyle _baseMapStyle(Object? raw) => switch (raw) {
  'satellite' => BaseMapStyle.satellite,
  'terrain' => BaseMapStyle.terrain,
  _ => BaseMapStyle.standard,
};

/// Finds a place by id in the current results, then the saved/bookmarked store.
Future<Place?> _findPlace(Ref ref, String id) async {
  for (final Place candidate in ref.read(searchControllerProvider).results) {
    if (candidate.id == id) {
      return candidate;
    }
  }
  return ref.read(placesRepositoryProvider).placeById(id);
}

/// The place key for a `review.list` request: the selected place's key, or an
/// explicit `id`/`placeKey` param.
Future<String> _placeKeyForRequest(Ref ref, CommandRequest request) async {
  final Object? rawKey = request.params['placeKey'];
  if (rawKey is String && rawKey.trim().isNotEmpty) {
    return rawKey.trim();
  }
  final Object? rawId = request.params['id'];
  if (rawId is String && rawId.trim().isNotEmpty) {
    return ReviewPlace.keyFor(rawId.trim());
  }
  final Place? place = ref.read(selectedPlaceProvider);
  if (place == null) {
    throw const CommandException(
      'no_place',
      'pass an "id"/"placeKey" or select a place first',
    );
  }
  return ReviewPlace.keyFor(place.id);
}

/// The position to use for a review badge whose place is not in our data: the
/// badge's own position, else the camera target.
LatLon _positionForPlaceKey(Ref ref, String placeKey) {
  for (final ReviewMarker marker in ref.read(reviewMarkersProvider)) {
    if (marker.placeKey == placeKey) {
      return marker.position;
    }
  }
  return ref.read(mapServiceProvider).camera.target;
}

/// Looks the OSM element up so a badge opened from the map shows the real name
/// and address instead of `node/2764050762`.
///
/// Returns `null` when the id is not an OSM reference or the lookup failed —
/// the caller then keeps a readable fallback rather than failing the tap. The
/// lookup is shared (and cached) with the place sheet through
/// [osmPlaceDetailsProvider].
Future<Place?> _lookupOsmPlace(Ref ref, String id) async {
  if (!OsmRef.isRef(id)) {
    return null;
  }
  return ref.read(osmPlaceDetailsProvider(id).future);
}

/// Resolves the place a command acts on — an explicit `id`, else the selected
/// place — and fills in its OpenStreetMap contact details (cached, so this is
/// cheap once the sheet has looked the place up).
///
/// Returns `null` when neither an id nor a selection is available.
Future<Place?> _resolvePlace(
  Ref ref,
  CommandRequest request, {
  bool enrich = true,
}) async {
  final Object? rawId = request.params['id'];
  Place? place;
  if (rawId is String && rawId.trim().isNotEmpty) {
    final String id = rawId.trim();
    place = await _findPlace(ref, id);
    place ??= await _lookupOsmPlace(ref, id);
  }
  place ??= ref.read(selectedPlaceProvider);
  if (place == null || !enrich) {
    return place;
  }
  return place.withOsmDetails(await _lookupOsmPlace(ref, place.id));
}

/// A trimmed, non-empty string parameter, or `null`.
String? _stringParam(CommandRequest request, String name) {
  final Object? raw = request.params[name];
  if (raw is! String) {
    return null;
  }
  final String value = raw.trim();
  return value.isEmpty ? null : value;
}

/// A short share line for a place: its name, address and OSM link / coordinates.
String _shareText(Place place) {
  final StringBuffer buffer = StringBuffer(place.name);
  final String? address = place.address;
  if (address != null && address.isNotEmpty) {
    buffer.write('\n$address');
  }
  final String link = OsmRef.isRef(place.id)
      ? 'https://www.openstreetmap.org/${place.id}'
      : 'https://www.openstreetmap.org/?mlat=${place.position.latitude}'
            '&mlon=${place.position.longitude}#map=17/'
            '${place.position.latitude}/${place.position.longitude}';
  buffer.write('\n$link');
  return buffer.toString();
}

/// A readable label for a place we could not resolve: `way/123` → "Way 123",
/// `poi.123` → "Poi 123".
String _fallbackPlaceName(String id) {
  final List<String> words = id
      .replaceAll(RegExp(r'[._/\-]+'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList(growable: false);
  if (words.isEmpty) {
    return 'Unnamed place';
  }
  return words
      .map(
        (String word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

/// The viewer's own review draft for [place], so editing prefills the sheet.
ReviewDraft? _draftFromSummary(Ref ref, Place place) {
  final String key = ReviewPlace.keyFor(place.id);
  final ReviewSummary summary = ref.read(placeReviewSummaryProvider(key));
  final String? me = ref.read(reviewServiceProvider).currentUserPubkey;
  if (me == null) {
    return null;
  }
  for (final Review review in summary.reviews) {
    if (review.authorPubkey == me) {
      return ReviewDraft(
        placeKey: key,
        position: place.position,
        rating: review.rating,
        text: review.bodyText,
        photoUrls: review.photos,
      );
    }
  }
  return null;
}

Map<String, Object?> _reviewJson(Review review) => <String, Object?>{
  'id': review.id,
  'placeKey': review.placeKey,
  'author': review.authorPubkey,
  if (review.authorName != null) 'name': review.authorName,
  'rating': review.rating,
  'stars': review.stars,
  'text': review.bodyText,
  'content': review.content,
  'photos': review.photos,
  'friend': review.isFriend,
  'lat': review.position.latitude,
  'lon': review.position.longitude,
  'createdAt': review.createdAt.toIso8601String(),
};

Map<String, Object?> _reviewSummaryJson(ReviewSummary summary) =>
    <String, Object?>{
      'placeKey': summary.placeKey,
      'count': summary.reviewCount,
      'friends': summary.friendCount,
      'averageRating': summary.averageRating,
      'stars': summary.stars,
      'reviews': summary.reviews.map(_reviewJson).toList(growable: false),
    };

Map<String, Object?> _reviewMarkerJson(ReviewMarker marker) =>
    <String, Object?>{
      'placeKey': marker.placeKey,
      'lat': marker.position.latitude,
      'lon': marker.position.longitude,
      'averageRating': marker.averageRating,
      'stars': marker.stars,
      'count': marker.reviewCount,
      'friends': marker.friendCount,
      'label': marker.badgeLabel,
    };

Map<String, Object?> _reviewComposerJson(ReviewComposerState state) {
  final ReviewDraft? draft = state.draft;
  return <String, Object?>{
    'open': state.isOpen,
    'status': state.status.name,
    if (state.place != null) 'place': _placeJson(state.place!),
    if (draft != null) ...<String, Object?>{
      'placeKey': draft.placeKey,
      'rating': draft.rating,
      'stars': state.stars,
      'text': draft.text,
      'visibility': draft.visibility.name,
      'localPhotos': draft.photos.length,
      'photoUrls': draft.photoUrls,
      'canPublish': draft.canPublish,
    },
    'error': state.error,
  };
}

Map<String, Object?> _itineraryJson(TransitItinerary itinerary) =>
    <String, Object?>{
      'durationSeconds': itinerary.duration.inSeconds,
      'startTime': itinerary.startTime.toIso8601String(),
      'endTime': itinerary.endTime.toIso8601String(),
      'transfers': itinerary.transfers,
      'walkingMeters': itinerary.walkingMeters,
      'realtime': itinerary.hasRealtime,
      'cancelled': itinerary.isCancelled,
      'departureDelaySeconds': itinerary.departureDelay?.inSeconds,
      'arrivalDelaySeconds': itinerary.arrivalDelay?.inSeconds,
      'agencies': itinerary.agencies,
      'lines': <String>[
        for (final TransitLeg leg in itinerary.rides) leg.lineLabel,
      ],
      'geometryPoints': itinerary.geometry.length,
      'legs': itinerary.legs.map(_transitLegJson).toList(growable: false),
    };

Map<String, Object?> _transitLegJson(TransitLeg leg) => <String, Object?>{
  'mode': leg.mode.motisName,
  'transit': leg.isTransit,
  if (leg.isTransit) 'line': leg.lineLabel,
  if (leg.headsign != null) 'headsign': leg.headsign,
  if (leg.agencyName != null) 'agency': leg.agencyName,
  'from': _transitStopJson(leg.from),
  'to': _transitStopJson(leg.to),
  'startTime': leg.startTime.toIso8601String(),
  'endTime': leg.endTime.toIso8601String(),
  'durationSeconds': leg.duration.inSeconds,
  'distanceMeters': leg.distanceMeters,
  'realtime': leg.realTime,
  'cancelled': leg.cancelled,
  'departureDelaySeconds': leg.departureDelay?.inSeconds,
  'arrivalDelaySeconds': leg.arrivalDelay?.inSeconds,
  'geometryPoints': leg.geometry.length,
};

Map<String, Object?> _transitStopJson(TransitStop stop) => <String, Object?>{
  'name': stop.name,
  if (stop.hasTrack) 'track': stop.displayTrack,
  if (stop.position != null) ...<String, Object?>{
    'lat': stop.position!.latitude,
    'lon': stop.position!.longitude,
  },
};

/// The result shared by the `transit.*` commands: the path's itineraries, or a
/// structured failure when the plan failed.
Object _transitResult(Ref ref) {
  final RouteState state = ref.read(routeControllerProvider);
  if (state.status == RouteStatus.error) {
    throw state.error ?? const UnknownException('Transit planning failed');
  }
  return state.itineraries.map(_itineraryJson).toList(growable: false);
}

/// The departures-board state (its status, stop and rows) for agents/tests.
Map<String, Object?> _departuresJson(
  TransitDeparturesState state,
) => <String, Object?>{
  'status': state.status.name,
  'stopId': state.stopId,
  'stopName': state.stopName,
  'departures': <Map<String, Object?>>[
    for (final TransitStopDeparture departure in state.departures)
      <String, Object?>{
        'line': departure.lineLabel,
        'headsign': departure.headsign,
        'mode': departure.mode.name,
        'departure': departure.displayDeparture.toIso8601String(),
        'scheduledDeparture': departure.scheduledDeparture?.toIso8601String(),
        'track': departure.displayTrack,
        'agency': departure.agencyName,
        'realTime': departure.realTime,
        'cancelled': departure.cancelled,
        'wheelchairAccessible': departure.wheelchairAccessible,
        'bikesAllowed': departure.bikesAllowed,
      },
  ],
};

/// A [Place] for a transit endpoint picked by coordinate.
Place _transitPlace(String id, LatLon position, {String? name}) => Place(
  id: 'transit-$id',
  name: name == null || name.trim().isEmpty ? 'Pinned point' : name.trim(),
  position: position,
);

List<Place> _transitStops(Object? raw) {
  if (raw is! List) {
    return const <Place>[];
  }
  final List<Place> stops = <Place>[];
  for (final Object? entry in raw) {
    final LatLon? point = _pointFrom(entry);
    if (point == null) {
      continue;
    }
    stops.add(
      _transitPlace('stop-${stops.length + 1}', point, name: _nameFrom(entry)),
    );
  }
  return stops;
}

String? _nameFrom(Object? raw) {
  if (raw is Map) {
    final Object? name = raw['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
  }
  return null;
}

DateTime? _timeFrom(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw.trim());
}

int? _intFrom(Object? raw) => switch (raw) {
  final int value => value,
  final double value => value.toInt(),
  final String value => int.tryParse(value),
  _ => null,
};

/// Parses a `modes` list of group names (`bus`, `tram`, `subway`, `train`,
/// `ferry`) or raw MOTIS mode names into a mode set.
Set<TransitMode> _transitModesFrom(Object? raw) {
  if (raw == null) {
    return const <TransitMode>{};
  }
  if (raw is! List) {
    throw const CommandException('bad_params', '"modes" must be a list');
  }
  final Set<TransitMode> modes = <TransitMode>{};
  for (final Object? entry in raw) {
    if (entry is! String || entry.trim().isEmpty) {
      continue;
    }
    final String value = entry.trim().toLowerCase();
    final TransitModeGroup? group = switch (value) {
      'bus' => TransitModeGroup.bus,
      'tram' => TransitModeGroup.tram,
      'subway' || 'metro' => TransitModeGroup.subway,
      'train' || 'rail' => TransitModeGroup.train,
      'ferry' => TransitModeGroup.ferry,
      _ => null,
    };
    if (group != null) {
      modes.addAll(group.modes);
      continue;
    }
    final TransitMode mode = transitModeFromMotis(entry);
    if (mode == TransitMode.other && value != 'other') {
      throw CommandException('bad_params', 'Unknown transit mode: $entry');
    }
    modes.add(mode);
  }
  return modes;
}

Map<String, Object?> _updateJson(UpdateState state) {
  final AppRelease? release = state.release;
  return <String, Object?>{
    'status': state.status.name,
    'installed': <String, Object?>{
      'versionCode': state.installed.versionCode,
      'versionName': state.installed.versionName,
    },
    'available': release == null
        ? null
        : <String, Object?>{
            'versionCode': release.versionCode,
            'versionName': release.versionName,
            'apkUrl': release.apkUrl.toString(),
            'sha256': release.sha256,
            'mandatory': release.mandatory,
            'releaseNotes': release.releaseNotes,
          },
    'skipped': state.skipped,
    'installing': state.installing,
    'progress': state.progress,
    'error': state.error,
  };
}

Map<String, Object?> _navJson(NavState nav) {
  final LatLon? position = nav.position;
  final TransitProgress? progress = nav.transitProgress;
  return <String, Object?>{
    'status': nav.status.name,
    'mode': nav.mode.name,
    'traveledMeters': nav.traveledMeters,
    'totalMeters': nav.totalMeters,
    'tripTraveledMeters': nav.tripTraveledMeters,
    'tripElapsedSeconds': nav.startedAt == null
        ? 0
        : DateTime.now().difference(nav.startedAt!).inSeconds,
    'remainingSeconds': nav.remaining.inSeconds,
    'distanceToNextManeuver': nav.distanceToNextManeuver,
    'instruction': nav.nextManeuver?.instruction,
    'speedMetersPerSecond': nav.speedMetersPerSecond,
    'overview': nav.overview,
    'cameraFollows': nav.cameraFollows,
    if (progress != null)
      'transit': <String, Object?>{
        'phase': progress.phase.name,
        'legIndex': progress.legIndex,
        'rideLegIndex': progress.rideLegIndex,
        'line': progress.ride?.lineLabel,
        'headsign': progress.ride?.headsign,
        'stopsRemaining': progress.stopsRemaining,
        'remainingInLegMeters': progress.remainingInLeg,
        'fractionInLeg': progress.fractionInLeg,
      },
    'position': position == null
        ? null
        : <String, Object?>{
            'lat': position.latitude,
            'lon': position.longitude,
          },
  };
}

double? _toDouble(Object? value) => switch (value) {
  final num v => v.toDouble(),
  final String v => double.tryParse(v),
  _ => null,
};

/// A finite double, or `null` for anything missing/non-finite (hostile params).
double? _finite(Object? value) {
  final double? parsed = _toDouble(value);
  return parsed != null && parsed.isFinite ? parsed : null;
}
