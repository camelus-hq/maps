import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_external_actions.dart';
import 'package:openmaps/data/fakes/fake_osm_place_source.dart';
import 'package:openmaps/data/fakes/fake_review_service.dart';
import 'package:openmaps/data/fakes/fake_social_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/place.dart';
import 'package:openmaps/features/directions/widgets/transit/transit_departure_row.dart';
import 'package:openmaps/features/place_details/widgets/place_details_sheet.dart';
import 'package:openmaps/state/place.dart';
import 'package:openmaps/state/ports.dart';
import 'package:openmaps/state/social.dart';

/// The station sheet: a public-transport stop gets a **Departures** tab before
/// Overview, its line chips, and an earlier/later paged departures list.
void main() {
  const Place station = Place(
    id: 'poi.station-1',
    name: 'Central Station',
    position: LatLon(52.525, 13.415),
    category: 'rail',
  );
  const Place cafe = Place(
    id: 'poi.cafe-1',
    name: 'Harbour Coffee',
    position: LatLon(52.521, 13.4075),
    category: 'Cafe',
  );

  ProviderContainer container() => ProviderContainer(
    overrides: <Override>[
      reviewServiceProvider.overrideWithValue(FakeReviewService()),
      socialServiceProvider.overrideWithValue(FakeSocialService()),
      osmPlaceSourceProvider.overrideWithValue(FakeOsmPlaceSource()),
      externalActionsProvider.overrideWithValue(FakeExternalActions()),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    ProviderContainer c,
    Place place,
  ) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await c.read(friendsProvider.future);
    c.read(selectedPlaceProvider.notifier).select(place);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: PlaceDetailsSheet(place: place)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> expand(WidgetTester tester) async {
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a transit stop shows Departures before Overview with its lines',
    (WidgetTester tester) async {
      final ProviderContainer c = container();
      addTearDown(c.dispose);
      await pump(tester, c, station);
      await expand(tester);

      expect(find.text('Departures'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      final double departuresX = tester.getTopLeft(find.text('Departures')).dx;
      final double overviewX = tester.getTopLeft(find.text('Overview')).dx;
      expect(
        departuresX,
        lessThan(overviewX),
        reason: 'Departures is the first tab',
      );

      // The lines serving the stop are shown as chips (fake service: S41/U8).
      expect(find.text('S41'), findsWidgets);
      expect(find.text('U8'), findsWidgets);

      // Opening the tab lists the departures with the earlier/later controls.
      await tester.tap(find.text('Departures'));
      await tester.pumpAndSettle();
      expect(find.text('Later departures'), findsOneWidget);
      expect(find.text('Earlier departures'), findsOneWidget);

      await tester.tap(find.text('Later departures'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('tapping a departure opens the train detail and back returns', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, station);
    await expand(tester);

    await tester.tap(find.text('Departures'));
    await tester.pumpAndSettle();

    final Finder row = find.byType(TransitDepartureRow).first;
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    // The train's detail: a back control and its stop list.
    expect(find.text('Back to departures'), findsOneWidget);
    expect(find.text('Fake terminus'), findsWidgets);
    expect(find.textContaining('stops'), findsWidgets);

    await tester.tap(find.text('Back to departures'));
    await tester.pumpAndSettle();
    expect(find.text('Back to departures'), findsNothing);
    expect(find.text('Later departures'), findsOneWidget);
  });

  testWidgets('a non-transit place has no Departures tab', (
    WidgetTester tester,
  ) async {
    final ProviderContainer c = container();
    addTearDown(c.dispose);
    await pump(tester, c, cafe);
    await expand(tester);

    expect(find.text('Departures'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
  });
}
