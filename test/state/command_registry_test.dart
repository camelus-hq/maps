import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/data/fakes/fake_external_actions.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/data/mapbox/mapbox_map_service.dart';
import 'package:openmaps/domain/entities/app_settings.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/lat_lon_bounds.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/ports/search_service.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/follow.dart';
import 'package:openmaps/state/home.dart';
import 'package:openmaps/state/map_camera.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/route.dart';
import 'package:openmaps/state/search.dart';
import 'package:openmaps/state/settings.dart';

void main() {
  // Some commands (ui.back) touch a GlobalKey, which needs the widget binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());

  tearDown(() => container.dispose());

  test('session.list includes the registered commands', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> list = await registry.list();
    final Set<Object?> ids = list
        .map((Object? entry) => (entry as Map<String, Object?>)['id'])
        .toSet();
    expect(
      ids,
      containsAll(<String>[
        'app.ready',
        'app.state',
        'map.camera.get',
        'map.camera.set',
        'ui.screenshot',
        'session.list',
        'session.help',
      ]),
    );
  });

  test('app.state reports ready, build mode and camera', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final Map<String, Object?> state = await registry.state();
    expect(state['ready'], isTrue);
    expect(state['buildMode'], isA<String>());
    expect(state['camera'], isA<Map<String, Object?>>());
  });

  test('map.camera.set then get reflects the new camera', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await registry.dispatch('map.camera.set', <String, Object?>{
      'lat': 48.1,
      'lon': 11.6,
      'zoom': 15,
    });
    final Map<String, Object?> camera = await registry.camera();
    expect(camera['lat'], 48.1);
    expect(camera['lon'], 11.6);
    expect(camera['zoom'], 15);
  });

  test('map.camera.set rejects hostile coordinates', () {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      () => registry.dispatch('map.camera.set', <String, Object?>{
        'lat': 999,
        'lon': 'x',
      }),
      throwsA(isA<CommandException>()),
    );
  });

  test('unknown command throws CommandException', () {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      () => registry.dispatch('nope', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });

  test('map.resetBearing zeroes bearing but keeps position and zoom', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await registry.dispatch('map.camera.set', <String, Object?>{
      'lat': 1.0,
      'lon': 2.0,
      'zoom': 10,
      'bearing': 45,
    });
    final Map<String, Object?> camera = await registry.dispatch(
      'map.resetBearing',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(camera['bearing'], 0.0);
    expect(camera['zoom'], 10.0);
    expect(camera['lat'], 1.0);
    // Resetting the bearing locks north-up so a fix does not rotate it away.
    expect(container.read(mapOrientationProvider), MapOrientation.north);
  });

  test(
    'map.orientation toggles north/direction and applies the mode',
    () async {
      final CommandRegistrySource registry = CommandRegistrySource(container);
      expect(container.read(mapOrientationProvider), MapOrientation.heading);

      expect(
        await registry.dispatch('map.orientation', const <String, Object?>{}),
        'north',
      );
      expect(container.read(mapOrientationProvider), MapOrientation.north);
      expect(
        container.read(mapServiceProvider).camera.bearing,
        0,
        reason: 'north mode must turn the map immediately',
      );

      expect(
        await registry.dispatch('map.orientation', const <String, Object?>{}),
        'heading',
      );
      expect(container.read(mapOrientationProvider), MapOrientation.heading);

      await expectLater(
        registry.dispatch('map.orientation', <String, Object?>{
          'mode': 'sideways',
        }),
        throwsA(isA<CommandException>()),
      );
    },
  );

  test('map.myLocation moves to the fake last-known fix', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final Map<String, Object?> camera = await registry.dispatch(
      'map.myLocation',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(camera['lat'], closeTo(52.52, 1e-9));
    expect(camera['lon'], closeTo(13.405, 1e-9));
  });

  test(
    'map.markers.set drops hostile entries and get returns the rest',
    () async {
      final CommandRegistrySource registry = CommandRegistrySource(container);
      final Map<String, Object?> result = await registry.dispatch(
        'map.markers.set',
        <String, Object?>{
          'markers': <Object?>[
            <String, Object?>{'id': 'a', 'lat': 1.0, 'lon': 2.0},
            <String, Object?>{'id': 'b', 'lat': 3.0, 'lon': 4.0},
            <String, Object?>{'id': 'bad', 'lat': 999, 'lon': 2.0},
            <String, Object?>{'lat': 5.0, 'lon': 6.0},
          ],
        },
      ) as Map<String, Object?>;
      expect(result['count'], 2);

      final List<Object?> markers = await registry.dispatch(
        'map.markers.get',
        const <String, Object?>{},
      ) as List<Object?>;
      expect(markers, hasLength(2));
      expect((markers.first as Map<String, Object?>)['id'], 'a');
    },
  );

  test('map.markers.clear empties the markers', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await registry.dispatch('map.markers.set', <String, Object?>{
      'markers': <Object?>[
        <String, Object?>{'id': 'a', 'lat': 1.0, 'lon': 2.0},
      ],
    });
    await registry.dispatch('map.markers.clear', const <String, Object?>{});
    final List<Object?> markers = await registry.dispatch(
      'map.markers.get',
      const <String, Object?>{},
    ) as List<Object?>;
    expect(markers, isEmpty);
  });

  test('search.query returns fake results and place.select focuses', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    expect(results, isNotEmpty);
    final Map<String, Object?> first = results.first as Map<String, Object?>;

    final Map<String, Object?> selected = await registry.dispatch(
      'place.select',
      <String, Object?>{'id': first['id']},
    ) as Map<String, Object?>;
    expect(selected['id'], first['id']);
    expect(selected['name'], first['name']);
  });

  test('place.select rejects an unknown id', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await expectLater(
      registry.dispatch('place.select', <String, Object?>{'id': 'nope'}),
      throwsA(isA<NotFoundException>()),
    );
  });

  test(
    'place.copyAddress copies the selected place and returns the address',
    () async {
      final CommandRegistrySource registry = CommandRegistrySource(container);
      final List<Object?> results = await registry.dispatch(
        'search.query',
        <String, Object?>{'text': 'coffee'},
      ) as List<Object?>;
      final Map<String, Object?> first = results.first as Map<String, Object?>;
      await registry.dispatch('place.select', <String, Object?>{
        'id': first['id'],
      });

      final Map<String, Object?> copied = await registry.dispatch(
        'place.copyAddress',
        const <String, Object?>{},
      ) as Map<String, Object?>;
      expect(copied['id'], first['id']);
      expect(copied['address'], isA<String>());
    },
  );

  test('place.copyAddress errors when nothing is selected', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await expectLater(
      registry.dispatch('place.copyAddress', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });

  test('place.nearby browses around the selected place', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('place.select', <String, Object?>{
      'id': first['id'],
    });

    final List<Object?> nearby = await registry.dispatch(
      'place.nearby',
      const <String, Object?>{},
    ) as List<Object?>;
    expect(nearby, isNotEmpty);
    expect(container.read(selectedCategoryProvider), isNotNull);
    expect(container.read(selectedPlaceProvider), isNull);
  });

  test('place.nearby with nothing selected throws', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await expectLater(
      registry.dispatch('place.nearby', const <String, Object?>{}),
      throwsA(isA<CommandException>()),
    );
  });

  test('app.tab selects the bottom-nav tab', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      await registry.dispatch('app.tab', <String, Object?>{'tab': 'you'}),
      'you',
    );
    expect(container.read(homeTabProvider), HomeTab.you);
    await expectLater(
      registry.dispatch('app.tab', <String, Object?>{'tab': 'nope'}),
      throwsA(isA<CommandException>()),
    );
  });

  test('app.settings.set updates and persists settings', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final Map<String, Object?> result = await registry.dispatch(
      'app.settings.set',
      <String, Object?>{
        'unit': 'imperial',
        'theme': 'dark',
        'showOsmTags': true,
        'searchBackend': 'openstreetmap',
      },
    ) as Map<String, Object?>;
    expect(result['unit'], 'imperial');
    expect(result['theme'], 'dark');
    expect(result['showOsmTags'], isTrue);
    expect(result['searchBackend'], 'openstreetmap');
    expect(container.read(settingsProvider).unit, DistanceUnit.imperial);

    final AppSettings persisted = await container
        .read(settingsRepositoryProvider)
        .load();
    expect(persisted.theme, AppThemeMode.dark);
    expect(persisted.showOsmTags, isTrue);
    expect(persisted.searchBackend, SearchBackend.openstreetmap);

    // The read-only command reports the same.
    final Map<String, Object?> read = await registry.dispatch(
      'app.settings',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(read['searchBackend'], 'openstreetmap');

    await expectLater(
      registry.dispatch('app.settings.set', <String, Object?>{'unit': 'nope'}),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      registry.dispatch('app.settings.set', <String, Object?>{
        'showOsmTags': 'yes',
      }),
      throwsA(isA<CommandException>()),
    );
    await expectLater(
      registry.dispatch('app.settings.set', <String, Object?>{
        'searchBackend': 'nope',
      }),
      throwsA(isA<CommandException>()),
    );

    // The Camelus service set is a third choice.
    final Map<String, Object?> camelus = await registry.dispatch(
      'app.settings.set',
      <String, Object?>{'searchBackend': 'camelus'},
    ) as Map<String, Object?>;
    expect(camelus['searchBackend'], 'camelus');
    expect(
      container.read(settingsProvider).searchBackend,
      SearchBackend.camelus,
    );
  });

  test('nav.overview toggles the route overview', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});
    await registry.dispatch('nav.start', const <String, Object?>{});

    final Map<String, Object?> on = await registry.dispatch(
      'nav.overview',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(on['overview'], isTrue);

    final Map<String, Object?> off = await registry.dispatch(
      'nav.overview',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(off['overview'], isFalse);
    expect(off['cameraFollows'], isTrue);
  });

  test('nav.pause and nav.resume drive camera tracking', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});
    await registry.dispatch('nav.start', const <String, Object?>{});

    final Map<String, Object?> paused = await registry.dispatch(
      'nav.pause',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(paused['cameraFollows'], isFalse);

    // The command channel reports it, and re-centering flips it back.
    final Map<String, Object?> resumed = await registry.dispatch(
      'nav.resume',
      const <String, Object?>{},
    ) as Map<String, Object?>;
    expect(resumed['cameraFollows'], isTrue);
  });

  test('app.onboarding sets and reads the flag', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      await registry.dispatch('app.onboarding', const <String, Object?>{}),
      isTrue,
    );
    expect(
      await registry.dispatch('app.onboarding', <String, Object?>{
        'seen': false,
      }),
      isFalse,
    );
    expect(
      await registry.dispatch('app.onboarding', <String, Object?>{
        'seen': true,
      }),
      isTrue,
    );
  });

  test('search.category browses on the map and stays there', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.category',
      <String, Object?>{'name': 'Cafes'},
    ) as List<Object?>;
    expect(results, isNotEmpty);
    // The map-local results sheet is the browse surface.
    expect(container.read(selectedCategoryProvider), 'Cafes');
    expect(container.read(searchControllerProvider).lastQuery, 'Cafes');

    await expectLater(
      registry.dispatch('search.category', <String, Object?>{'name': 'Nope'}),
      throwsA(isA<CommandException>()),
    );

    await registry.dispatch('search.category', const <String, Object?>{});
    expect(container.read(searchControllerProvider).results, isEmpty);
    expect(container.read(selectedCategoryProvider), isNull);
  });

  test('search.category accepts an id as well as a label', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.category',
      <String, Object?>{'name': 'drinking_water'},
    ) as List<Object?>;
    expect(results, isNotEmpty);
    expect(container.read(selectedCategoryProvider), 'Water fountain');
  });

  test('search.category reports a provider that has no category index', () async {
    final ProviderContainer local = ProviderContainer(
      overrides: <Override>[
        searchServiceProvider.overrideWithValue(const _UnsupportedSearch()),
      ],
    );
    addTearDown(local.dispose);
    final CommandRegistrySource registry = CommandRegistrySource(local);

    await expectLater(
      registry.dispatch('search.category', <String, Object?>{
        'name': 'toilets',
      }),
      throwsA(isA<CommandException>()),
    );
    // The sheet shows the typed error; there is no silent text-search fallback
    // and the previous category's pins are dropped.
    expect(local.read(searchControllerProvider).status, SearchStatus.error);
    expect(local.read(searchControllerProvider).results, isEmpty);
    expect((local.read(mapServiceProvider) as FakeMapService).markers, isEmpty);
  });

  test('a single result does not zoom in past a street level', () async {
    final ProviderContainer local = ProviderContainer(
      overrides: <Override>[
        searchServiceProvider.overrideWithValue(const _SingleResultSearch()),
      ],
    );
    addTearDown(local.dispose);
    final CommandRegistrySource registry = CommandRegistrySource(local);

    await registry.dispatch('search.category', <String, Object?>{
      'name': 'drinking_water',
    });

    final FakeMapService map = local.read(mapServiceProvider) as FakeMapService;
    expect(map.markers, hasLength(1));
    // Fitting a single point would otherwise fill the viewport at ~20×.
    expect(map.camera.zoom, lessThanOrEqualTo(MapboxMapService.maxFitZoom));
    expect(map.camera.zoom, greaterThanOrEqualTo(14));
  });

  test('search.pin and search.unpin move a chip on and off the row', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final Map<String, Object?> already = await registry.dispatch(
      'search.pin',
      <String, Object?>{'name': 'Parking'},
    ) as Map<String, Object?>;
    expect(already['added'], isTrue);
    expect(already['pinned'], contains('parking'));

    final Map<String, Object?> removed = await registry.dispatch(
      'search.unpin',
      <String, Object?>{'name': 'parking'},
    ) as Map<String, Object?>;
    expect(removed['pinned'], isNot(contains('parking')));

    await expectLater(
      registry.dispatch('search.pin', <String, Object?>{'name': 'Nope'}),
      throwsA(isA<CommandException>()),
    );
  });

  test('search.pin stops at the pin limit', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<String> extra = <String>[
      'restaurant',
      'bar',
      'hotel',
      'bank',
      'pharmacy',
      'parking',
    ];
    for (final String id in extra) {
      await registry.dispatch('search.pin', <String, Object?>{'name': id});
    }
    // 5 defaults + 6 pins > 10: the last ones are refused.
    expect(container.read(settingsProvider).pinnedCategoryIds.length, 10);
    final Map<String, Object?> refused = await registry.dispatch(
      'search.pin',
      <String, Object?>{'name': 'cinema'},
    ) as Map<String, Object?>;
    expect(refused['added'], isFalse);
  });

  test('clearing a category removes its result pins from the map', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;

    await registry.dispatch('search.category', <String, Object?>{
      'name': 'Cafes',
    });
    expect(map.markers, isNotEmpty, reason: 'browsing draws the category pins');

    // Deselecting the chip / closing the sheet clears with an empty params map.
    await registry.dispatch('search.category', const <String, Object?>{});
    expect(
      map.markers,
      isEmpty,
      reason: 'the POIs must not stay drawn after the sheet closes',
    );
  });

  test('ui.tap rejects hostile coordinates', () {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      () => registry.dispatch('ui.tap', <String, Object?>{
        'x': 'nope',
        'y': null,
      }),
      throwsA(isA<CommandException>()),
    );
  });

  test('ui.back is a safe no-op when no app is mounted', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      await registry.dispatch('ui.back', const <String, Object?>{}),
      isFalse,
    );
  });

  test('route.request returns a fake route with steps', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> routes = await registry.dispatch(
      'route.request',
      <String, Object?>{
        'origin': <String, Object?>{'lat': 52.52, 'lon': 13.405},
        'destination': <String, Object?>{'lat': 52.53, 'lon': 13.42},
        'mode': 'walk',
      },
    ) as List<Object?>;
    expect(routes, isNotEmpty);
    final Map<String, Object?> route = routes.first as Map<String, Object?>;
    expect(route['distanceMeters'], greaterThan(0));
    expect(route['durationSeconds'], greaterThan(0));
    expect(route['geometryPoints'], greaterThan(0));
    expect(route['steps'], isA<List<Object?>>());
  });

  test('route.request rejects missing endpoints', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    await expectLater(
      registry.dispatch('route.request', <String, Object?>{
        'origin': <String, Object?>{'lat': 1.0, 'lon': 2.0},
      }),
      throwsA(isA<CommandException>()),
    );
  });

  test('route.plan draws a fake route and the map receives it', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;

    final Map<String, Object?> route = await registry.dispatch(
      'route.plan',
      <String, Object?>{'id': first['id']},
    ) as Map<String, Object?>;
    expect(route['distanceMeters'], greaterThan(0));
    expect(route['steps'], isA<List<Object?>>());

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.routeLines, isNotEmpty);
  });

  test('route.mode returns the new mode', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    expect(
      await registry.dispatch('route.mode', <String, Object?>{'mode': 'walk'}),
      'walk',
    );
  });

  test('route.addStop and route.removeStop update the stops', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});

    await registry.dispatch('route.addStop', <String, Object?>{
      'id': first['id'],
    });
    expect(container.read(routeControllerProvider).stops, hasLength(1));

    await registry.dispatch('route.removeStop', <String, Object?>{'index': 0});
    expect(container.read(routeControllerProvider).stops, isEmpty);

    await expectLater(
      registry.dispatch('route.removeStop', <String, Object?>{'index': 0}),
      throwsA(isA<CommandException>()),
    );
  });

  test('route.origin and route.swap update the endpoints', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});

    await registry.dispatch('route.swap', const <String, Object?>{});
    final RouteState swapped = container.read(routeControllerProvider);
    expect(swapped.destination, isNotNull);
    expect(swapped.origin, isNotNull);
  });

  test(
    'route endpoints can be picked, replaced and set to my location',
    () async {
      final CommandRegistrySource registry = CommandRegistrySource(container);
      final List<Object?> results = await registry.dispatch(
        'search.query',
        <String, Object?>{'text': 'coffee'},
      ) as List<Object?>;
      final String id =
          (results.first as Map<String, Object?>)['id']! as String;
      await registry.dispatch('route.plan', <String, Object?>{'id': id});

      // Editing a field opens the place picker for it.
      await registry.dispatch('route.editEndpoint', <String, Object?>{
        'field': 'destination',
      });
      expect(
        container.read(routeControllerProvider).editingEndpoint,
        const RouteEndpointTarget.destination(),
      );
      await registry.dispatch(
        'route.endpoint.close',
        const <String, Object?>{},
      );
      expect(container.read(routeControllerProvider).editingEndpoint, isNull);

      // Adding a stop, then replacing it by index.
      await registry.dispatch('route.addStop', <String, Object?>{'id': id});
      final String second =
          ((await registry.dispatch('search.query', <String, Object?>{
                    'text': 'park',
                  }) as List<Object?>).first
                  as Map<String, Object?>)['id']!
              as String;
      await registry.dispatch('route.setStop', <String, Object?>{
        'index': 0,
        'id': second,
      });
      expect(container.read(routeControllerProvider).stops.first.id, second);

      // "Your location" for the start.
      await registry.dispatch('route.useCurrentLocation', <String, Object?>{
        'field': 'origin',
      });
      expect(
        container.read(routeControllerProvider).origin?.name,
        'Your location',
      );
    },
  );

  test(
    'route.pickOnMap can arm a stop, and setStop rejects bad input',
    () async {
      final CommandRegistrySource registry = CommandRegistrySource(container);
      final List<Object?> results = await registry.dispatch(
        'search.query',
        <String, Object?>{'text': 'coffee'},
      ) as List<Object?>;
      final String id =
          (results.first as Map<String, Object?>)['id']! as String;
      await registry.dispatch('route.plan', <String, Object?>{'id': id});

      await registry.dispatch('route.pickOnMap', <String, Object?>{
        'field': 'stop',
      });
      expect(
        container.read(routeControllerProvider).pickTarget,
        const RouteEndpointTarget.stop(),
      );

      await expectLater(
        registry.dispatch('route.setStop', <String, Object?>{
          'index': 0,
          'id': id,
        }),
        throwsA(isA<CommandException>()),
      );
      await expectLater(
        registry.dispatch('route.editEndpoint', <String, Object?>{
          'field': 'sideways',
        }),
        throwsA(isA<CommandException>()),
      );
    },
  );

  test('mapLongPressProvider forwards long-press coordinates', () async {
    final ProviderSubscription<AsyncValue<LatLon>> sub = container.listen(
      mapLongPressProvider,
      (AsyncValue<LatLon>? previous, AsyncValue<LatLon> next) {},
    );
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    await pumpEventQueue();
    map.emitLongPress(const LatLon(1, 2));
    await pumpEventQueue();
    expect(container.read(mapLongPressProvider).value, const LatLon(1, 2));
    sub.close();
  });

  test('route.pickOnMap then a long-press sets the origin', () async {
    final CommandRegistrySource registry = CommandRegistrySource(container);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final Map<String, Object?> first = results.first as Map<String, Object?>;
    await registry.dispatch('route.plan', <String, Object?>{'id': first['id']});
    await registry.dispatch('route.pickOnMap', <String, Object?>{
      'field': 'origin',
    });
    await pumpEventQueue();

    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    map.emitLongPress(const LatLon(52.5, 13.4));
    await pumpEventQueue();

    final RouteState state = container.read(routeControllerProvider);
    expect(state.origin?.name, 'Dropped pin');
    expect(state.pickTarget, isNull);
  });

  group('place details + contact commands', () {
    const Place willow = Place(
      id: 'node/111',
      name: 'Willow Park',
      position: LatLon(52.5150, 13.4030),
      phone: '030 53166994',
      email: 'hi@willow.example',
      website: 'instagram.com/willow',
      wheelchairAccessible: true,
      openingHours: 'Mo-Fr 08:00-18:00',
    );

    late FakeExternalActions external;
    late FakeOsmPlaceSource osm;
    late ProviderContainer local;

    setUp(() {
      external = FakeExternalActions();
      osm = FakeOsmPlaceSource();
      local = ProviderContainer(
        overrides: <Override>[
          externalActionsProvider.overrideWithValue(external),
          osmPlaceSourceProvider.overrideWithValue(osm),
        ],
      );
    });

    tearDown(() => local.dispose());

    Future<Object?> run(
      String id, [
      Map<String, Object?> params = const <String, Object?>{},
    ]) => local.read(commandRegistryProvider).dispatch(id, params);

    test('place.details merges the OSM contact facts', () async {
      osm.seed(willow.id, willow);
      final Map<String, Object?> details = await run(
        'place.details',
        <String, Object?>{'id': willow.id},
      ) as Map<String, Object?>;
      expect(details['name'], 'Willow Park');
      expect(details['phone'], '030 53166994');
      expect(details['email'], 'hi@willow.example');
      expect(details['website'], 'instagram.com/willow');
      expect(details['wheelchairAccessible'], isTrue);
      expect(details['openingHours'], 'Mo-Fr 08:00-18:00');
    });

    test(
      'place.details returns the raw OSM tags, images and payments',
      () async {
        osm.seed(
          willow.id,
          const Place(
            id: 'node/111',
            name: 'Willow Park',
            position: LatLon(52.5150, 13.4030),
            osmTags: <String, String>{
              'payment:cash': 'yes',
              'payment:lightning': 'yes',
              'image': 'https://example.org/willow.jpg',
              'takeaway': 'only',
            },
          ),
        );
        final Map<String, Object?> details = await run(
          'place.details',
          <String, Object?>{'id': willow.id},
        ) as Map<String, Object?>;
        expect(details['osmTags'], containsPair('payment:cash', 'yes'));
        expect(details['images'], <String>['https://example.org/willow.jpg']);
        expect(details['payments'], containsPair('lightning', 'yes'));
      },
    );

    test('place.call opens the dialler with the OSM number', () async {
      osm.seed(willow.id, willow);
      final Map<String, Object?> result = await run(
        'place.call',
        <String, Object?>{'id': willow.id},
      ) as Map<String, Object?>;
      expect(result['phone'], '030 53166994');
      expect(result['launched'], isTrue);
      expect(external.calls, <String>['030 53166994']);
    });

    test('place.call takes an explicit number without a place', () async {
      final Map<String, Object?> result = await run(
        'place.call',
        <String, Object?>{'phone': '112'},
      ) as Map<String, Object?>;
      expect(result['launched'], isTrue);
      expect(external.calls, <String>['112']);
    });

    test('place.call without any number is a typed error', () {
      osm.seed(
        'node/222',
        const Place(id: 'node/222', name: 'X', position: LatLon(1, 2)),
      );
      expect(
        () => run('place.call', <String, Object?>{'id': 'node/222'}),
        throwsA(isA<CommandException>()),
      );
    });

    test('place.email and place.openWebsite reach the device', () async {
      osm.seed(willow.id, willow);
      await run('place.email', <String, Object?>{'id': willow.id});
      await run('place.openWebsite', <String, Object?>{'id': willow.id});
      expect(external.emails, <String>['hi@willow.example']);
      expect(external.websites, <String>['instagram.com/willow']);
    });

    test('place.share returns a share line with the OSM link', () async {
      osm.seed(willow.id, willow);
      final Map<String, Object?> result = await run(
        'place.share',
        <String, Object?>{'id': willow.id},
      ) as Map<String, Object?>;
      expect(result['text'], contains('Willow Park'));
      expect(
        result['text'],
        contains('https://www.openstreetmap.org/node/111'),
      );
    });
  });
}

/// Thin test helper around the registry provider.
class CommandRegistrySource {
  CommandRegistrySource(this._container);

  final ProviderContainer _container;

  Future<Object?> dispatch(String id, Map<String, Object?> params) =>
      _container.read(commandRegistryProvider).dispatch(id, params);

  Future<List<Object?>> list() async =>
      await dispatch('session.list', const <String, Object?>{})
          as List<Object?>;

  Future<Map<String, Object?>> state() async =>
      await dispatch('app.state', const <String, Object?>{})
          as Map<String, Object?>;

  Future<Map<String, Object?>> camera() async =>
      await dispatch('map.camera.get', const <String, Object?>{})
          as Map<String, Object?>;
}

/// A search backend with no POI category index (like Mapbox for an amenity it
/// does not cover): browsing must surface the error, never substitute a text
/// search.
class _UnsupportedSearch implements SearchService {
  const _UnsupportedSearch();

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async => const <Place>[];

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) async => throw UnsupportedException('No category "$categoryId"');
}

/// A backend that returns exactly one POI (the "water fountain" case).
class _SingleResultSearch implements SearchService {
  const _SingleResultSearch();

  @override
  Future<List<Place>> search(
    String query, {
    LatLon? proximity,
    LatLonBounds? bounds,
  }) async => const <Place>[];

  @override
  Future<List<Place>> nearbyCategory(
    String categoryId, {
    required LatLon proximity,
    LatLonBounds? bounds,
    int limit = 10,
  }) async => const <Place>[
    Place(
      id: 'node/1',
      name: 'Drinking water',
      position: LatLon(52.52, 13.405),
    ),
  ];
}
