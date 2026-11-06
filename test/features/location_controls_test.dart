import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/app/app.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/location_sample.dart';
import 'package:openmaps/domain/ports/location_service.dart';
import 'package:openmaps/state/follow.dart';
import 'package:openmaps/state/ports.dart';

class _ControllableLocationService implements LocationService {
  final StreamController<LocationSample> _controller =
      StreamController<LocationSample>.broadcast();
  LocationSample? _last;

  @override
  Future<LocationSample?> lastKnown() async => _last;

  @override
  Stream<LocationSample> positionStream() => _controller.stream;

  void emit(LocationSample sample) {
    _last = sample;
    _controller.add(sample);
  }

  void fail() => _controller.addError(StateError('gps'));

  Future<void> dispose() => _controller.close();
}

void main() {
  testWidgets('the location button reflects a lost GPS signal', (
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
    expect(find.byIcon(Icons.location_searching), findsOneWidget);

    // Lock on (follow) with a live fix → the filled "following" control.
    location.emit(const LocationSample(position: LatLon(52.52, 13.405)));
    await container.read(followModeProvider.notifier).enable();
    await tester.pump();
    expect(find.byIcon(Icons.my_location), findsOneWidget);

    // The signal drops → the button shows the lost state but follow stays on,
    // so the last known location is still shown greyed out by the puck overlay.
    location.fail();
    await tester.pump();
    expect(find.byIcon(Icons.gps_off), findsOneWidget);
    expect(find.byIcon(Icons.my_location), findsNothing);
    expect(container.read(followModeProvider), isTrue);
  });
}
