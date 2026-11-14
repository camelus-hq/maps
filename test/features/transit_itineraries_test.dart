import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_transit_routing_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/features/directions/screens/directions_sheet.dart';
import 'package:openmaps/features/directions/widgets/transit_itineraries.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/route.dart';

void main() {
  const LatLon origin = LatLon(52.52, 13.4);
  const LatLon destination = LatLon(52.5, 13.3);

  Future<List<TransitItinerary>> journeys() =>
      FakeTransitRoutingService(now: DateTime.utc(2026, 1, 1, 9))
          .plan(const TransitQuery(origin: origin, destination: destination));

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('a journey card shows the lines and the live delay', (
    WidgetTester tester,
  ) async {
    final List<TransitItinerary> itineraries = await journeys();
    await tester.pumpWidget(
      wrap(
        TransitItineraryCard(
          itinerary: itineraries.first,
          selected: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('M2'), findsOneWidget);
    expect(find.text('Departing'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('1 min late'), findsOneWidget);
    expect(find.text('City Transit'), findsWidgets);
  });

  testWidgets('the detail view shows the timeline, transfer tracks and Start', (
    WidgetTester tester,
  ) async {
    final List<TransitItinerary> itineraries = await journeys();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransitJourneyDetail(
              itinerary: itineraries[1],
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('U5'), findsWidgets);
    expect(find.text('S1'), findsWidgets);
    // The single change shows the platform at the boarding stops.
    expect(find.text('Central Station'), findsOneWidget);
    expect(find.text('Platform 3'), findsOneWidget);
    expect(find.text('Platform 7'), findsOneWidget);
    expect(find.text('Walk 4 min (260 m)'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  testWidgets('the detail Start button begins guidance', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': <String, Object?>{'lat': 52.52, 'lon': 13.4},
      'destination': <String, Object?>{'lat': 52.5, 'lon': 13.3},
    });
    await registry.dispatch('transit.detail', const <String, Object?>{});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DirectionsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();

    expect(
      container.read(navigationControllerProvider).status,
      NavStatus.navigating,
    );
  });

  testWidgets('a ride expands its stops', (WidgetTester tester) async {
    final List<TransitItinerary> itineraries = await journeys();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransitJourneyDetail(
              itinerary: itineraries.first,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );

    // The ride duration and its stop count sit together; the stops are hidden.
    expect(find.text('12 min'), findsWidgets);
    expect(find.text('1 stop'), findsOneWidget);
    expect(find.text('Harbour Road'), findsNothing);

    await tester.tap(find.text('1 stop'));
    await tester.pumpAndSettle();

    expect(find.text('Harbour Road'), findsOneWidget);
  });

  testWidgets('the directions sheet offers Transit, then a detail on tap', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': <String, Object?>{'lat': 52.52, 'lon': 13.4},
      'destination': <String, Object?>{'lat': 52.5, 'lon': 13.3},
    });

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

    // Step 1: the list with the transit controls. "Transit" appears both as the
    // sheet title and as the selected mode segment (as in the reference app).
    expect(find.text('Transit'), findsWidgets);
    expect(find.text('Leave now'), findsOneWidget);
    expect(find.text('Fewer transfers'), findsOneWidget);
    expect(find.byType(TransitItineraryCard), findsWidgets);

    // Step 2: tapping a journey opens the detail with the Start button.
    await tester.tap(find.byType(TransitItineraryCard).first);
    await tester.pumpAndSettle();
    expect(container.read(routeControllerProvider).transitDetailOpen, isTrue);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
    expect(find.text('Leave now'), findsNothing);

    // Closing returns to the list.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(container.read(routeControllerProvider).transitDetailOpen, isFalse);
    expect(find.text('Leave now'), findsOneWidget);
  });

  testWidgets(
    'the timeline draws mode nodes and shows the wait before a ride',
    (WidgetTester tester) async {
      final List<TransitItinerary> itineraries = await journeys();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: TransitJourneyDetail(
                itinerary: itineraries.first,
                scrollController: ScrollController(),
              ),
            ),
          ),
        ),
      );

      // A node for the tram ride; the walk legs' own icons too.
      expect(find.byIcon(Icons.tram), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsNWidgets(2));
      // The 1 min gap between arriving and the tram's departure.
      expect(find.text('Wait 1 min'), findsOneWidget);
    },
  );

  testWidgets('the sticky footer carries the duration and arrival time', (
    WidgetTester tester,
  ) async {
    final List<TransitItinerary> itineraries = await journeys();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransitJourneyDetail(
              itinerary: itineraries.first,
              scrollController: ScrollController(),
            ),
          ),
        ),
      ),
    );

    // The whole-journey duration sits with the Start action, not in the list.
    expect(find.text('19 min'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });

  test('waitBefore is the gap between legs and zero elsewhere', () async {
    final List<TransitItinerary> itineraries = await journeys();
    final TransitItinerary first = itineraries.first;
    expect(first.waitBefore(0), Duration.zero);
    expect(first.waitBefore(1), const Duration(minutes: 1));
    expect(first.waitBefore(2), Duration.zero);
    expect(first.waitBefore(-1), Duration.zero);
    expect(first.waitBefore(99), Duration.zero);
  });

  testWidgets('the detail sheet can collapse to a small peek', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(commandRegistryProvider);
    await registry.dispatch('transit.plan', <String, Object?>{
      'origin': <String, Object?>{'lat': 52.52, 'lon': 13.4},
      'destination': <String, Object?>{'lat': 52.5, 'lon': 13.3},
    });
    await registry.dispatch('transit.detail', const <String, Object?>{});

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

    // Three snap points: a small peek, half, and near-full.
    final DraggableScrollableSheet sheet = tester
        .widget<DraggableScrollableSheet>(
          find.byType(DraggableScrollableSheet),
        );
    expect(sheet.minChildSize, lessThan(0.2));
    expect(sheet.snapSizes, containsAll(<double>[0.5, 0.92]));
    expect(sheet.snapSizes, hasLength(3));

    // Dragging the header down collapses to the peek: the header and the
    // Start/duration row stay, and the sheet is still draggable (controller).
    await tester.drag(
      find.byType(TransitLineBadge).first,
      const Offset(0, 600),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Start'), findsOneWidget);
  });
}
