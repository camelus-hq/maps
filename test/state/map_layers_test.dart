import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/fakes/fake_map_service.dart';
import 'package:openmaps/domain/entities/map_style.dart';
import 'package:openmaps/state/commands/commands_provider.dart';
import 'package:openmaps/state/map_layers.dart';
import 'package:openmaps/state/ports.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  FakeMapService map() => container.read(mapServiceProvider) as FakeMapService;

  Future<Object?> dispatch(
    String id, [
    Map<String, Object?> params = const <String, Object?>{},
  ]) => container.read(commandRegistryProvider).dispatch(id, params);

  test(
    'map.style.set switches the base style; map.style.get reads it',
    () async {
      expect(
        await dispatch('map.style.set', <String, Object?>{
          'style': 'satellite',
        }),
        'satellite',
      );
      expect(map().baseStyle, BaseMapStyle.satellite);
      expect(await dispatch('map.style.get'), 'satellite');

      // Unknown values fall back to the default.
      expect(
        await dispatch('map.style.set', <String, Object?>{'style': 'nope'}),
        'standard',
      );
      expect(map().baseStyle, BaseMapStyle.standard);
    },
  );

  test('map.traffic toggles the overlay and reports the state', () async {
    expect(await dispatch('map.traffic'), isTrue);
    expect(map().trafficEnabled, isTrue);
    expect(
      await dispatch('map.traffic', <String, Object?>{'on': false}),
      isFalse,
    );
    expect(map().trafficEnabled, isFalse);
  });

  test('place.bookmark saves a place and paints a star marker', () async {
    final List<Object?> results = await dispatch(
      'search.query',
      <String, Object?>{'text': 'coffee'},
    ) as List<Object?>;
    final String id = (results.first as Map<String, Object?>)['id']! as String;

    expect(
      await dispatch('place.bookmark', <String, Object?>{'id': id}),
      isTrue,
    );
    expect(map().savedMarkers, hasLength(1));
    expect(map().savedMarkers.single.id, id);

    final List<Object?> saved =
        await dispatch('place.bookmarks') as List<Object?>;
    expect(saved, hasLength(1));

    await dispatch('place.bookmark', <String, Object?>{
      'id': id,
      'bookmarked': false,
    });
    expect(map().savedMarkers, isEmpty);
  });

  test('mapStyleProvider and trafficProvider mirror the service', () async {
    await container
        .read(mapStyleProvider.notifier)
        .select(BaseMapStyle.terrain);
    expect(container.read(mapStyleProvider), BaseMapStyle.terrain);
    expect(map().baseStyle, BaseMapStyle.terrain);

    await container.read(trafficProvider.notifier).toggle();
    expect(container.read(trafficProvider), isTrue);
    expect(map().trafficEnabled, isTrue);
  });
}
