import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/state/home.dart';
import 'package:openmaps/state/ports.dart';
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
}
