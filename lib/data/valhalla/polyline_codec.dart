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

/// Encodes [points] as a Google/Valhalla polyline (precision 6 by default).
///
/// Used to hand a route geometry back to Valhalla's `/height` service, which
/// expects the encoded shape rather than raw coordinates.
String encodePolyline(List<LatLon> points, {int precision = 6}) {
  final int factor = math.pow(10, precision).toInt();
  final StringBuffer buffer = StringBuffer();
  int lastLat = 0;
  int lastLng = 0;
  for (final LatLon point in points) {
    final int lat = (point.latitude * factor).round();
    final int lng = (point.longitude * factor).round();
    _encodeValue(buffer, lat - lastLat);
    _encodeValue(buffer, lng - lastLng);
    lastLat = lat;
    lastLng = lng;
  }
  return buffer.toString();
}

void _encodeValue(StringBuffer buffer, int value) {
  int v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}
