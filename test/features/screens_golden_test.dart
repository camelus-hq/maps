import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/domain/ports/places_repository.dart';
import 'package:openmaps/features/directions/screens/directions_sheet.dart';
import 'package:openmaps/features/directions/screens/endpoint_picker_screen.dart';
import 'package:openmaps/features/directions/widgets/directions_endpoint_card.dart';
import 'package:openmaps/features/place_details/widgets/place_details_sheet.dart';
import 'package:openmaps/features/saved/screens/saved_screen.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/ports.dart';

/// Screen-level goldens guarding the parity we've reached.
///
/// The real Mapbox surface is a platform view and cannot be a golden, so the
/// home/search goldens render the keyless placeholder; the sheet goldens render
/// the sheet directly over the app theme.
///
/// **Regression policy:** an intentional UI change updates the goldens in the
/// same commit (`flutter test --update-goldens`); an unintentional diff fails
/// CI. Never update a golden to hide a regression — fix the code instead.
void main() {
  void setSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  const Place samplePlace = Place(
    id: 'poi.coffee',
    name: 'Harbour Coffee',
    position: LatLon(52.5208, 13.4095),
    category: 'Cafe',
    address: 'Alexanderufer 1, Berlin',
  );

  testWidgets('the empty search screen with recents matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final PlacesRepository repo = container.read(placesRepositoryProvider);
    await repo.setHome(
      const Place(
        id: 'home',
        name: 'Home',
        position: LatLon(52.5170, 13.3889),
        address: 'Paul-Löbe-Allee 1, Berlin',
      ),
    );
    await repo.recordRecentPlace(
      const Place(
        id: 'recent.1',
        name: 'Königin-Luise-Gedächtniskirche',
        position: LatLon(52.458, 13.29),
        category: 'Church',
        address: 'Gustav-Müller-Platz, 10829 Berlin',
      ),
    );
    await repo.recordRecentPlace(
      const Place(
        id: 'recent.2',
        name: 'go asia Supermarkt',
        position: LatLon(52.53, 13.41),
        category: 'Supermarket',
        address: 'Hauptstraße 132, 10827 Berlin',
      ),
    );
    await repo.recordRecentQuery('Alexanderplatz');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_recent.png'),
    );
  });

  testWidgets('search results match the golden', (WidgetTester tester) async {
    setSurface(tester);
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_results.png'),
    );
  });

  testWidgets('saved empty state matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const SavedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/saved_empty.png'),
    );
  });

  testWidgets('place details sheet matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PlaceDetailsSheet(place: samplePlace)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/place_details.png'),
    );
  });

  testWidgets('directions sheet matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: DirectionsSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/directions_sheet.png'),
    );
  });

  testWidgets('the map home with directions open matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/directions_open.png'),
    );
  });

  testWidgets('directions endpoint card matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});
    await registry.dispatch('route.addStop', <String, Object?>{'id': id});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            backgroundColor: Color(0xFFDDE3E0),
            body: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: DirectionsEndpointCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/directions_endpoint_card.png'),
    );
  });

  testWidgets('endpoint picker matches the golden', (
    WidgetTester tester,
  ) async {
    setSurface(tester);
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    final List<Object?> results = await registry.dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;
    await registry.dispatch('route.plan', <String, Object?>{'id': id});
    await registry.dispatch('route.editEndpoint', <String, Object?>{
      'field': 'destination',
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const EndpointPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/endpoint_picker.png'),
    );
  });
}
