import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/data/fakes/fake_location_service.dart';
import 'package:openmaps/data/fakes/fake_settings_repository.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/ports.dart';

/// A [LocationService] that only records how it was accessed (and delegates the
/// values to [FakeLocationService]). Lets a test prove the device location is
/// not touched until the user allows it.
class _RecordingLocationService implements LocationService {
  int positionStreamCalls = 0;
  int availabilityStreamCalls = 0;
  int lastKnownCalls = 0;

  static const FakeLocationService _values = FakeLocationService();

  @override
  Future<LocationSample?> lastKnown() {
    lastKnownCalls++;
    return _values.lastKnown();
  }

  @override
  Stream<LocationSample> positionStream() {
    positionStreamCalls++;
    return _values.positionStream();
  }

  @override
  Stream<bool> availabilityStream() {
    availabilityStreamCalls++;
    return _values.availabilityStream();
  }
}

void main() {
  testWidgets('first run: accept the terms, choose location, then the map', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await repository.setOnboardingSeen(false);
    final _RecordingLocationService location = _RecordingLocationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: the terms, with the policy links, and no location access yet.
    expect(find.text('Welcome to Camelus Maps'), findsOneWidget);
    expect(find.text('Accept & continue'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Turn on location'), findsNothing);
    expect(find.text('Search here'), findsNothing);
    expect(location.positionStreamCalls, 0);
    expect(location.availabilityStreamCalls, 0);
    expect(location.lastKnownCalls, 0);

    // Step 2: accepting the terms reveals the location rationale — still
    // without touching the device location.
    await tester.tap(find.text('Accept & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on location'), findsOneWidget);
    expect(find.text('Allow location & continue'), findsOneWidget);
    expect(location.positionStreamCalls, 0);
    expect(location.lastKnownCalls, 0);

    // Declining ends onboarding; the map appears and location tracking starts.
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Camelus Maps'), findsNothing);
    expect(find.text('Search here'), findsOneWidget);
    expect(location.positionStreamCalls, greaterThan(0));
    expect(await repository.onboardingSeen(), isTrue);
  });

  testWidgets('allowing location ends onboarding and asks for a fix', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository repository = FakeSettingsRepository();
    await repository.setOnboardingSeen(false);
    final _RecordingLocationService location = _RecordingLocationService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repository),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accept & continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow location & continue'));
    await tester.pumpAndSettle();

    expect(find.text('Search here'), findsOneWidget);
    expect(location.lastKnownCalls, greaterThan(0));
    expect(await repository.onboardingSeen(), isTrue);
  });
}
