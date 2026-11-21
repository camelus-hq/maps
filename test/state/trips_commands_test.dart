import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/core/errors/app_exception.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/travel_mode.dart';
import 'package:openmaps/domain/entities/trip.dart';
import 'package:openmaps/state/commands/command.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/settings.dart';
import 'package:openmaps/state/trips.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  Future<Object?> dispatch(
    String id, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) => container.read(commandRegistryProvider).dispatch(id, params);

  Trip trip(String id) => Trip(
    id: id,
    startedAt: DateTime.utc(2026, 5, 1, 9),
    endedAt: DateTime.utc(2026, 5, 1, 9, 30),
    mode: TravelMode.cycle,
    distanceMeters: 4200,
    destinationName: 'Office',
    track: const <LatLon>[LatLon(52.52, 13.40), LatLon(52.53, 13.42)],
  );

  test('trips.list / get report recorded trips', () async {
    await container.read(recentTripsProvider.notifier).record(trip('a'));

    final List<Object?> list = await dispatch('trips.list') as List<Object?>;
    expect(list, hasLength(1));
    final Map<String, Object?> first = list.single as Map<String, Object?>;
    expect(first['id'], 'a');
    expect(first['points'], 2);
    expect(first['destination'], 'Office');

    final Map<String, Object?> got = await dispatch(
      'trips.get',
      <String, Object?>{'id': 'a'},
    ) as Map<String, Object?>;
    expect(got['distanceMeters'], 4200);
  });

  test('trips.get throws a typed error for an unknown id', () async {
    await expectLater(
      dispatch('trips.get', <String, Object?>{'id': 'nope'}),
      throwsA(isA<AppException>()),
    );
  });

  test('trips.export writes a GPX file and returns its text', () async {
    await container.read(recentTripsProvider.notifier).record(trip('a'));
    final Directory dir = Directory.systemTemp.createTempSync('openmaps-gpx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final String path = '${dir.path}/a.gpx';

    final Map<String, Object?> result = await dispatch(
      'trips.export',
      <String, Object?>{'id': 'a', 'path': path},
    ) as Map<String, Object?>;
    expect(result['path'], path);
    final String gpx = result['gpx'] as String;
    expect(gpx, contains('<trkpt lat="52.520000" lon="13.400000"/>'));
    expect(File(path).readAsStringSync(), gpx);
  });

  test('trips.delete and trips.clear empty the list', () async {
    await container.read(recentTripsProvider.notifier).record(trip('a'));
    await container.read(recentTripsProvider.notifier).record(trip('b'));

    await dispatch('trips.delete', <String, Object?>{'id': 'a'});
    expect(container.read(recentTripsProvider).map((Trip t) => t.id), <String>[
      'b',
    ]);

    await dispatch('trips.clear');
    expect(container.read(recentTripsProvider), isEmpty);
  });

  test('app.settings.set changes the recent-trips keep-limit', () async {
    final Map<String, Object?> result = await dispatch(
      'app.settings.set',
      <String, Object?>{'recentTripsLimit': 10},
    ) as Map<String, Object?>;
    expect(result['recentTripsLimit'], 10);
    expect(container.read(settingsProvider).recentTripsLimit, 10);

    await expectLater(
      dispatch('app.settings.set', <String, Object?>{'recentTripsLimit': 7}),
      throwsA(isA<CommandException>()),
    );
  });
}
