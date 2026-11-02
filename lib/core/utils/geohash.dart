/// Geohash encoding/decoding (base32, the classic Gustavo Niemeyer scheme) with
/// the small helpers our map/review queries need.
///
/// Pure Dart, no dependencies: L0 code that both the publish path (writing a
/// review's `g` tags) and the query path (covering the visible viewport) use.
///
/// Reviews carry a geohash so a relay can be asked for "everything under this
/// prefix" instead of "every review in the world" — one tag, many precisions.
library;

/// A latitude/longitude pair, kept as a record so this L0 file depends on no
/// domain entity.
typedef GeoCenter = ({double latitude, double longitude});

abstract final class Geohash {
  /// The geohash base32 alphabet (excludes `a`, `i`, `l`, `o`).
  static const String base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// The longest sensible precision (12 characters ≈ 3.7 cm × 1.9 cm).
  static const int maxPrecision = 12;

  /// Encodes [latitude]/[longitude] into a geohash of [precision] characters.
  ///
  /// [precision] is clamped to `1..maxPrecision`. Out-of-range coordinates are
  /// clamped so hostile input can never throw here.
  static String encode(
    double latitude,
    double longitude, {
    int precision = maxPrecision,
  }) {
    final int chars = precision.clamp(1, maxPrecision);
    final double lat = latitude.clamp(-90.0, 90.0);
    final double lon = longitude.clamp(-180.0, 180.0);

    double latMin = -90;
    double latMax = 90;
    double lonMin = -180;
    double lonMax = 180;

    final StringBuffer buffer = StringBuffer();
    bool even = true; // sequence starts with longitude
    int bit = 0;
    int value = 0;

    while (buffer.length < chars) {
      if (even) {
        final double mid = (lonMin + lonMax) / 2;
        if (lon >= mid) {
          value = (value << 1) | 1;
          lonMin = mid;
        } else {
          value = value << 1;
          lonMax = mid;
        }
      } else {
        final double mid = (latMin + latMax) / 2;
        if (lat >= mid) {
          value = (value << 1) | 1;
          latMin = mid;
        } else {
          value = value << 1;
          latMax = mid;
        }
      }
      even = !even;
      if (++bit == 5) {
        buffer.write(base32[value]);
        bit = 0;
        value = 0;
      }
    }
    return buffer.toString();
  }

  /// Encodes [latitude]/[longitude], returning `null` for anything missing,
  /// non-finite or out of range (so hostile input is dropped, never thrown).
  static String? tryEncode(
    Object? latitude,
    Object? longitude, {
    int precision = maxPrecision,
  }) {
    final double? lat = _finite(latitude);
    final double? lon = _finite(longitude);
    if (lat == null || lon == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return null;
    }
    return encode(lat, lon, precision: precision);
  }

  /// The centre of [hash] as a [GeoCenter], or `null` when [hash] is not a
  /// valid geohash.
  static GeoCenter? tryDecode(String hash) {
    final String clean = hash.trim().toLowerCase();
    if (clean.isEmpty || clean.length > maxPrecision) {
      return null;
    }
    double latMin = -90;
    double latMax = 90;
    double lonMin = -180;
    double lonMax = 180;
    bool even = true;
    for (final int rune in clean.codeUnits) {
      final int index = base32.indexOf(String.fromCharCode(rune));
      if (index < 0) {
        return null;
      }
      for (int mask = 16; mask > 0; mask >>= 1) {
        if (even) {
          final double mid = (lonMin + lonMax) / 2;
          if ((index & mask) != 0) {
            lonMin = mid;
          } else {
            lonMax = mid;
          }
        } else {
          final double mid = (latMin + latMax) / 2;
          if ((index & mask) != 0) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        even = !even;
      }
    }
    return (latitude: (latMin + latMax) / 2, longitude: (lonMin + lonMax) / 2);
  }

  /// The nested geohashes for [hash]: the full value first, then one character
  /// shorter each time, down to [minPrecision] characters.
  ///
  /// This is exactly what the reviews' `g` tags store: the full-precision hash
  /// for an exact point, plus every enclosing prefix so a single `#g` filter at
  /// any zoom level finds the event.
  static List<String> prefixes(String hash, {int minPrecision = 1}) {
    final String clean = hash.trim().toLowerCase();
    if (clean.isEmpty) {
      return const <String>[];
    }
    final int floor = minPrecision.clamp(1, clean.length);
    final List<String> values = <String>[];
    for (int length = clean.length; length >= floor; length--) {
      values.add(clean.substring(0, length));
    }
    return values;
  }

  /// Every geohash cell of [precision] that covers the given rectangle.
  ///
  /// The rectangle is sampled on the cells' own grid, and the list is
  /// de-duplicated. The number of samples is capped, so a huge (whole-world)
  /// viewport degrades to a coarse cover rather than a hang — callers that care
  /// should pick a [precision] whose cell size is proportional to the viewport.
  static List<String> cover({
    required double north,
    required double south,
    required double east,
    required double west,
    required int precision,
    int maxCells = 64,
  }) {
    final int p = precision.clamp(1, maxPrecision);
    // Geohash interleaves, starting with longitude: lon gets the extra bit.
    final int totalBits = 5 * p;
    final int lonBits = (totalBits + 1) ~/ 2;
    final int latBits = totalBits ~/ 2;
    final double cellLat = 180 / _pow2(latBits);
    final double cellLon = 360 / _pow2(lonBits);

    double latLow = south;
    double latHigh = north;
    if (latLow > latHigh) {
      final double swap = latLow;
      latLow = latHigh;
      latHigh = swap;
    }
    latLow = latLow.clamp(-90.0, 90.0);
    latHigh = latHigh.clamp(-90.0, 90.0);

    // Longitude spans may exceed 360 (not our case); wrap into [-180, 180].
    double lonLow = west;
    double lonHigh = east;
    if (lonLow > lonHigh) {
      final double swap = lonLow;
      lonLow = lonHigh;
      lonHigh = swap;
    }
    final double lonSpan = (lonHigh - lonLow).clamp(0.0, 359.999);
    lonLow = _wrapLongitude(lonLow);
    lonHigh = lonLow + lonSpan;

    final int latSteps = _steps(latHigh - latLow, cellLat, maxCells);
    final int lonSteps = _steps(lonSpan, cellLon, maxCells);

    final Set<String> cells = <String>{};
    for (int i = 0; i <= latSteps; i++) {
      final double lat = latLow + (latHigh - latLow) * (i / latSteps);
      for (int j = 0; j <= lonSteps; j++) {
        final double lon = lonLow + lonSpan * (j / lonSteps);
        cells.add(encode(lat, _wrapLongitude(lon), precision: p));
      }
    }
    return cells.toList(growable: false);
  }

  /// A longitude wrapped into `[-180, 180)`.
  static double _wrapLongitude(double value) {
    double lon = value;
    while (lon < -180) {
      lon += 360;
    }
    while (lon >= 180) {
      lon -= 360;
    }
    return lon;
  }

  static int _steps(double span, double cell, int maxCells) {
    if (cell <= 0 || span <= 0) {
      return 0;
    }
    final int raw = (span / cell).ceil();
    final int capped = raw < 1 ? 1 : raw;
    return capped > maxCells ? maxCells : capped;
  }

  static double _pow2(int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 2;
    }
    return result;
  }

  static double? _finite(Object? value) {
    final double? parsed = switch (value) {
      final double v => v,
      final int v => v.toDouble(),
      final String v => double.tryParse(v),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      return null;
    }
    return parsed;
  }
}
