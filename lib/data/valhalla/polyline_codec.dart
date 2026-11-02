import 'dart:math' as math;

import '../../domain/entities/lat_lon.dart';

/// Decodes a Google/Valhalla encoded polyline into coordinates.
///
/// Valhalla uses precision 6. Hostile/truncated input never throws — decoding
/// stops and returns what it has.
List<LatLon> decodePolyline(String encoded, {int precision = 6}) {
  final List<LatLon> points = <LatLon>[];
  final int factor = math.pow(10, precision).toInt();
  int index = 0;
  int lat = 0;
  int lng = 0;

  while (index < encoded.length) {
    final (int, int)? latResult = _decodeValue(encoded, index);
    if (latResult == null) {
      break;
    }
    lat += latResult.$1;
    index = latResult.$2;

    final (int, int)? lngResult = _decodeValue(encoded, index);
    if (lngResult == null) {
      break;
    }
    lng += lngResult.$1;
    index = lngResult.$2;

    final LatLon? point = LatLon.tryParse(lat / factor, lng / factor);
    if (point != null) {
      points.add(point);
    }
  }
  return points;
}

/// Returns the signed delta and the next index, or `null` if truncated.
(int, int)? _decodeValue(String encoded, int index) {
  int result = 0;
  int shift = 0;
  int current;
  do {
    if (index >= encoded.length) {
      return null;
    }
    current = encoded.codeUnitAt(index++) - 63;
    result |= (current & 0x1f) << shift;
    shift += 5;
  } while (current >= 0x20);
  final int delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (delta, index);
}
