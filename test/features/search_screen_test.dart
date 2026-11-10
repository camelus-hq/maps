import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/state/home.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/saved_places.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

void main() {
  testWidgets('typing in search shows fake results', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Harbour Coffee'), findsOneWidget);

    // Each row leads with its own category glyph — a cafe gets a coffee cup —
    // not the generic pin.
    expect(find.byIcon(PhosphorIconsRegular.coffee), findsWidgets);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets(
    'submitting a category query returns to the map with the results sheet',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const OpenMapsApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search here'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Back on the map (not the search list), with the category sheet open and
      // the cafes pinned.
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Search here'), findsOneWidget);
      expect(container.read(selectedCategoryProvider), 'Cafes');
      expect(
        (container.read(mapServiceProvider) as FakeMapService).markers,
        isNotEmpty,
      );
    },
  );

  testWidgets('a category query shows a tappable category result at the top', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // The chip name leads the results, with a coloured magnifying glass.
    final Finder suggestion = find.widgetWithText(ListTile, 'Cafes');
    expect(suggestion, findsOneWidget);
    final Icon icon = tester.widget<Icon>(
      find.descendant(of: suggestion, matching: find.byIcon(Icons.search)),
    );
    expect(icon.color, isNotNull);

    await tester.tap(suggestion);
    await tester.pumpAndSettle();

    // Tapping it browses the category and returns to the map.
    expect(container.read(selectedCategoryProvider), 'Cafes');
    expect(
      (container.read(mapServiceProvider) as FakeMapService).markers,
      isNotEmpty,
    );
  });

  testWidgets('selecting a result returns to the map with the place selected', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Harbour Coffee'));
    await tester.pumpAndSettle();

    // Back on the map, the place-details sheet is open (its actions are shown).
    expect(find.text('Directions'), findsOneWidget);
  });

  testWidgets(
    'the empty search screen shows Home, Work and the recent header',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search here'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      // Neither slot is set yet.
      expect(find.text('Add'), findsNWidgets(2));
      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Clear recents'), findsOneWidget);
    },
  );

  testWidgets('selecting a place adds it to the recent list', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Coffee'));
    await tester.pumpAndSettle();
    await container.read(recentSearchesProvider.notifier).recordQuery('pizza');

    // Reopening search shows the place in "Recent", with its category glyph,
    // alongside the text query (clock).
    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    expect(find.text('Harbour Coffee'), findsOneWidget);
    expect(find.text('pizza'), findsOneWidget);
    expect(find.byIcon(PhosphorIconsRegular.coffee), findsWidgets);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('tapping a recent place opens it on the map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Coffee'));
    await tester.pumpAndSettle();

    // Reopen search and tap the recent row: it must open the place again
    // (a recent place is resolvable even though it is not bookmarked).
    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Directions'), findsOneWidget);
    expect(find.text('Harbour Coffee'), findsOneWidget);
  });

  testWidgets('"Add" under Home picks a place and saves it', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add').first); // Home
    await tester.pumpAndSettle();
    expect(find.text('Set home'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harbour Coffee'));
    await tester.pumpAndSettle();

    expect(container.read(savedPlacesProvider).home?.name, 'Harbour Coffee');
  });

  testWidgets('"Clear recents" empties the list', (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search here'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(container.read(recentSearchesProvider), isNotEmpty);
    await container.read(recentSearchesProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(container.read(recentSearchesProvider), isEmpty);
  });
}
