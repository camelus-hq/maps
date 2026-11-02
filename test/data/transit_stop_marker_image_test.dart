import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/transit_stop_marker_image.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';
import 'package:openmaps/domain/entities/transit_stop_marker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const TransitStopMarker pass = TransitStopMarker(
    id: 'a',
    position: LatLon(52.5, 13.4),
  );
  const TransitStopMarker board = TransitStopMarker(
    id: 'b',
    position: LatLon(52.5, 13.4),
    emphasis: TransitStopEmphasis.board,
    color: 0xFF1F6FB2,
  );

  test('a boarding circle is larger than a pass-through circle', () {
    expect(
      TransitStopMarkerComposer.imageSize(TransitStopEmphasis.board),
      greaterThan(
        TransitStopMarkerComposer.imageSize(TransitStopEmphasis.pass),
      ),
    );
  });

  test('composes PNG bytes and caches them', () async {
    final TransitStopMarkerComposer composer = TransitStopMarkerComposer();
    addTearDown(composer.dispose);

    final List<int> passBytes = await composer.compose(pass);
    final List<int> boardBytes = await composer.compose(board);

    expect(passBytes, isNotEmpty);
    expect(boardBytes, isNotEmpty);
    // The two variants differ, and the same marker returns the cached bytes.
    expect(passBytes, isNot(equals(boardBytes)));
    expect(await composer.compose(pass), same(passBytes));
    expect(composer.cachedBytes(pass), passBytes);
  });

  test('a hostile/absent colour does not throw', () async {
    final TransitStopMarkerComposer composer = TransitStopMarkerComposer();
    addTearDown(composer.dispose);
    expect(() => composer.compose(pass), returnsNormally);
  });
}
