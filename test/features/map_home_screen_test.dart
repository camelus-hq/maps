import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/features/map_home/widgets/map_surface_placeholder.dart';
import 'package:openmaps/features/social/widgets/friend_avatar.dart';
import 'package:openmaps/state/home.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  testWidgets('map home renders the shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Search here'), findsOneWidget);
    // 'Explore' now labels both the feed header and the bottom-nav destination.
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Contribute'), findsOneWidget);
    // The pinned chip row, in order, followed by the settings chip.
    // (`find.text` also sees offstage chips in the horizontal list.)
    expect(find.text('Parks'), findsOneWidget);
    expect(find.text('Cafes'), findsOneWidget);
    expect(find.text('Water fountain'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Toilets'), findsOneWidget);
    expect(find.byIcon(Icons.settings, skipOffstage: false), findsOneWidget);
    // The search pill carries logo/mic/avatar slots and the chips carry icons.
    // The default keyless build is signed in, so the account slot is the
    // profile avatar, not the signed-out person glyph.
    expect(find.byIcon(Icons.mic_none), findsOneWidget);
    expect(find.byType(FriendAvatar), findsOneWidget);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.byIcon(Icons.park), findsOneWidget);
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
  });

  testWidgets('the soft keyboard does not resize the map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    final Size atRest = tester.getSize(find.byType(MapSurfacePlaceholder));
    final double logicalHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // Sanity: the map fills the whole window before the keyboard appears.
    expect(atRest.height, logicalHeight);

    // A keyboard covering the bottom third of the screen (physical pixels).
    tester.view.viewInsets = FakeViewPadding(
      bottom: logicalHeight / 3 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    // The map must not move or shrink — the map-home Scaffold opts out of
    // resizing for the keyboard so a native Mapbox view stays put.
    expect(tester.getSize(find.byType(MapSurfacePlaceholder)), atRest);
  });

  testWidgets('bottom navigation switches the home feed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: OpenMapsApp()));
    await tester.pumpAndSettle();

    expect(find.text('Explore'), findsWidgets);

    await tester.tap(find.text('Contribute'));
    await tester.pumpAndSettle();
    expect(find.text('Contributions are not available yet'), findsOneWidget);

    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.text('Saved places'), findsOneWidget);
  });

  testWidgets('a category chip selects, keeps the map and pins the results', (
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

    final Finder chip = find.widgetWithText(FilterChip, 'Cafes');
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));

    // Still on the map (no search screen), with the category sheet open, the
    // chip selected and the cafe pins drawn on the map.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Search here'), findsOneWidget);
    expect(container.read(selectedCategoryProvider), 'Cafes');
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    final FakeMapService map =
        container.read(mapServiceProvider) as FakeMapService;
    expect(map.markers, isNotEmpty);

    // Tapping it again deselects and clears the pins.
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(container.read(selectedCategoryProvider), isNull);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);
    expect(map.markers, isEmpty);
  });
}
