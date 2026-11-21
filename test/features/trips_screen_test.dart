import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openmaps/data/fakes/fake_trips_repository.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';
import 'package:openmaps/features/trips/screens/trip_detail_screen.dart';
import 'package:openmaps/features/trips/screens/trips_screen.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  Trip trip({String destination = 'Office'}) => Trip(
    id: 'trip-1',
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    endedAt: DateTime.now(),
    mode: TravelMode.cycle,
    distanceMeters: 4200,
    destinationName: destination,
    track: const <LatLon>[LatLon(52.52, 13.40), LatLon(52.53, 13.42)],
  );

  Future<void> pump(WidgetTester tester, FakeTripsRepository repo) async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[tripsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TripsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists the recorded trips with a distance and duration', (
    WidgetTester tester,
  ) async {
    final FakeTripsRepository repo = FakeTripsRepository();
    await repo.recordTrip(trip(), maxTrips: 10);

    await pump(tester, repo);

    expect(find.text('Recent trips'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.textContaining('4.2 km'), findsOneWidget);
  });

  testWidgets('shows an empty state with no trips', (
    WidgetTester tester,
  ) async {
    await pump(tester, FakeTripsRepository());

    expect(
      find.textContaining('No trips yet. Start navigation'),
      findsOneWidget,
    );
  });

  testWidgets('the detail page renders the track and exports GPX', (
    WidgetTester tester,
  ) async {
    final FakeTripsRepository repo = FakeTripsRepository();
    await repo.recordTrip(trip(), maxTrips: 10);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[tripsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TripDetailScreen(tripId: 'trip-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trip'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Export GPX'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // recorded points

    await tester.tap(find.text('Export GPX'));
    await tester.pumpAndSettle();
    expect(find.textContaining('GPX'), findsWidgets);
  });
}
