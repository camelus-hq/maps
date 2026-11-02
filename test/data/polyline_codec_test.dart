import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/valhalla/polyline_codec.dart';
import 'package:openmaps/domain/entities/lat_lon.dart';

void main() {
  test('decodes a precision-6 polyline', () {
    final List<LatLon> points = decodePolyline('??o}@_|B');
    expect(points, hasLength(2));
    expect(points.first.latitude, closeTo(0, 1e-6));
    expect(points.first.longitude, closeTo(0, 1e-6));
    expect(points.last.latitude, closeTo(0.001, 1e-6));
    expect(points.last.longitude, closeTo(0.002, 1e-6));
  });

  test('decodes a precision-5 polyline', () {
    final List<LatLon> points = decodePolyline(
      '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      precision: 5,
    );
    expect(points, hasLength(3));
    expect(points.first.latitude, closeTo(38.5, 1e-5));
    expect(points.first.longitude, closeTo(-120.2, 1e-5));
  });

  test('never throws on hostile input', () {
    for (final String encoded in <String>['', 'garbage', '?????', '~', '\\']) {
      expect(() => decodePolyline(encoded), returnsNormally);
    }
  });
}
