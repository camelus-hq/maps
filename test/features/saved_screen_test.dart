import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/features/saved/screens/saved_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  testWidgets('saved screen lists bookmarked places', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(placesRepositoryProvider)
        .setBookmark(
          const Place(
            id: 'saved-spot',
            name: 'Saved Spot',
            position: LatLon(52.52, 13.405),
            address: '1 Example Street',
          ),
          bookmarked: true,
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SavedScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved Spot'), findsOneWidget);
    expect(find.text('1 Example Street'), findsOneWidget);
  });

  testWidgets('saved screen shows an empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SavedScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved places yet'), findsOneWidget);
  });
}
