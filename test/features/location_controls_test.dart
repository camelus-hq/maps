import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/features/design/play.dart';
import 'package:openmaps/state/follow.dart';
import 'package:openmaps/state/ports.dart';

class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  final StreamController<bool> _availability =
      StreamController<bool>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  @override
  Stream<bool> availabilityStream() => _availability.stream;

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  void setAvailability(bool available) => _availability.add(available);

  Future<void> dispose() async {
    await _controller.close();
    await _availability.close();
  }
}

void main() {
  testWidgets('the location button reflects unavailable location services', (
    WidgetTester tester,
  ) async {
    final _ControllableLocationService location =
        _ControllableLocationService();
    final ProviderContainer container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(location)],
    );
    addTearDown(() async {
      container.dispose();
      await location.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const OpenMapsApp(),
      ),
    );
    await tester.pumpAndSettle();

    // No fix yet → the neutral "show my location" control.
    expect(find.byIcon(PlayIcons.locate), findsOneWidget);

    // Lock on (follow) with a live fix → the filled "following" control.
    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    await container.read(followModeProvider.notifier).enable();
    await tester.pump();
    expect(find.byIcon(PlayIcons.locate), findsOneWidget);

    // Location services turn off → the button shows the alert state but follow
    // stays on, so the last known location is still shown greyed out.
    location.setAvailability(false);
    // The availability event is delivered in a microtask, so the first pump
    // only hands it to the tracker; the second draws the rebuilt control.
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(PlayIcons.locationLost), findsOneWidget);
    expect(find.byIcon(PlayIcons.locate), findsNothing);
    expect(container.read(followModeProvider), isTrue);

    // Services come back → the control returns to normal.
    location.setAvailability(true);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(PlayIcons.locationLost), findsNothing);
    expect(find.byIcon(PlayIcons.locate), findsOneWidget);
  });
}
