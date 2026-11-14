import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/core/theme/app_theme.dart';
import 'package:openmaps/data/fakes/fake_transit_routing_service.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/features/directions/widgets/transit/transit_common.dart';
import 'package:openmaps/features/directions/widgets/transit/transit_departures_sheet.dart';
import 'package:openmaps/features/directions/widgets/transit/transit_timeline.dart';
import 'package:openmaps/features/navigation/nav_style.dart';
import 'package:openmaps/features/navigation/widgets/transit_nav_banner.dart';
import 'package:openmaps/state/navigation.dart';
import 'package:openmaps/state/transit_departures.dart';

void main() {
  const LatLon origin = LatLon(52.52, 13.4);
  const LatLon destination = LatLon(52.5, 13.3);

  Future<TransitItinerary> journey() async {
    final List<TransitItinerary> all = await FakeTransitRoutingService(
      now: DateTime.utc(2026, 1, 1, 9),
    ).plan(const TransitQuery(origin: origin, destination: destination));
    return all.first;
  }

  double walkLengthOf(TransitItinerary itinerary) {
    final List<LatLon> line = itinerary.legs.first.geometry;
    return line.first.distanceTo(line.last);
  }

  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('the transit banner shows the action and the line status', (
    WidgetTester tester,
  ) async {
    final TransitItinerary itinerary = await journey();
    final TransitProgress progress = itinerary.progressAt(0);
    await tester.pumpWidget(
      wrap(
        TransitNavBanner(
          nav: NavState(
            status: NavStatus.navigating,
            mode: TravelMode.transit,
            transit: itinerary,
            transitProgress: progress,
          ),
          itinerary: itinerary,
          progress: progress,
          style: NavStyle.forMode(TravelMode.transit),
          imperial: false,
        ),
      ),
    );

    // The immediate action and the line's punctuality + platform.
    expect(find.text('Board M2 to Market Square'), findsOneWidget);
    expect(find.text('M2'), findsOneWidget);
    expect(find.textContaining('1 min late'), findsOneWidget);
    expect(find.text('Platform 1'), findsOneWidget);
    // The live chip is gone.
    expect(find.text('Live'), findsNothing);
  });

  testWidgets('the transit banner reports stops left while riding', (
    WidgetTester tester,
  ) async {
    final TransitItinerary itinerary = await journey();
    final TransitProgress progress = itinerary.progressAt(
      walkLengthOf(itinerary) + 200,
    );
    await tester.pumpWidget(
      wrap(
        TransitNavBanner(
          nav: NavState(
            status: NavStatus.navigating,
            mode: TravelMode.transit,
            transit: itinerary,
            transitProgress: progress,
          ),
          itinerary: itinerary,
          progress: progress,
          style: NavStyle.forMode(TravelMode.transit),
          imperial: false,
        ),
      ),
    );

    // On board the headline is the ride's remaining time, not the distance, and
    // the strip carries the stops left and the arrival clock.
    expect(find.textContaining('Market Square'), findsWidgets);
    expect(find.textContaining('km'), findsNothing);
    expect(find.textContaining('stops'), findsWidgets);
  });

  test('relative departure labels cover now, soon and recently', () {
    final DateTime now = DateTime.utc(2026, 1, 1, 12);
    expect(
      relativeTimeLabel(now.add(const Duration(seconds: 20)), now: now),
      'now',
    );
    expect(
      relativeTimeLabel(now.add(const Duration(minutes: 5)), now: now),
      'in 5 min',
    );
    expect(
      relativeTimeLabel(now.subtract(const Duration(minutes: 3)), now: now),
      '3 min ago',
    );
    expect(
      relativeTimeLabel(now.subtract(const Duration(minutes: 30)), now: now),
      isNull,
    );
    expect(
      relativeTimeLabel(now.add(const Duration(minutes: 90)), now: now),
      isNull,
    );
  });

  testWidgets('the timeline marks the live step with the navigation arrow', (
    WidgetTester tester,
  ) async {
    final TransitItinerary itinerary = await journey();
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: TransitTimeline(
            itinerary: itinerary,
            originName: 'Start',
            destinationName: 'Destination',
            imperial: false,
            liveLegIndex: 1,
            liveFraction: 0.4,
          ),
        ),
      ),
    );

    // The indicator is measured after layout, so pump past the post-frame pass.
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.navigation), findsOneWidget);
  });

  testWidgets('tapping a stop on the timeline opens its departures', (
    WidgetTester tester,
  ) async {
    final TransitItinerary itinerary = await journey();
    TransitStop? tapped;
    await tester.pumpWidget(
      wrap(
        SingleChildScrollView(
          child: TransitTimeline(
            itinerary: itinerary,
            originName: 'Start',
            destinationName: 'Destination',
            imperial: false,
            onStopTap: (TransitStop stop) => tapped = stop,
          ),
        ),
      ),
    );

    await tester.tap(find.text('North Street').first);
    await tester.pump();
    expect(tapped?.id, 'fake:stop-a');
  });

  testWidgets('the departures board lists the stop\'s next departures', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    await container
        .read(transitDeparturesProvider.notifier)
        .open(stopId: 'fake:stop-a', stopName: 'North Street');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrap(const TransitDeparturesSheet()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Departures'), findsOneWidget);
    expect(find.text('From North Street'), findsOneWidget);
    expect(find.text('S41'), findsWidgets);
  });
}
