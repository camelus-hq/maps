import '../entities/lat_lon.dart';
import '../entities/trip.dart';

/// Serialises a [Trip] to GPX 1.1 — a single `trk` with one `trkseg` of
/// `trkpt` points.
///
/// Pure and dependency-free (no XML package, no I/O): the output is a string so
/// it can be written to a file, copied to the clipboard or returned over the
/// control channel. Names are XML-escaped and bounded, so a hostile stored value
/// can never produce a malformed document (AGENTS.md §Never crash).
abstract final class TripGpx {
  static const String _creator = 'OpenMaps';

  static String encode(Trip trip) {
    final String name = _escape(trip.title);
    final StringBuffer out = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
        '<gpx version="1.1" creator="$_creator" '
        'xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..writeln('  <metadata>')
      ..writeln('    <name>$name</name>')
      ..writeln('    <time>${trip.startedAt.toUtc().toIso8601String()}</time>')
      ..writeln('  </metadata>')
      ..writeln('  <trk>')
      ..writeln('    <name>$name</name>')
      ..writeln('    <type>${trip.mode.name}</type>')
      ..writeln('    <trkseg>');
    for (final LatLon point in trip.track) {
      out.writeln(
        '      <trkpt lat="${_coord(point.latitude)}" '
        'lon="${_coord(point.longitude)}"/>',
      );
    }
    out
      ..writeln('    </trkseg>')
      ..writeln('  </trk>')
      ..writeln('</gpx>');
    return out.toString();
  }

  /// A coordinate with six decimals (≈11 cm), the usual GPX precision. A
  /// non-finite value (which a `LatLon` should not hold, but the store is
  /// untrusted) degrades to `0` rather than emitting `NaN`.
  static String _coord(double value) =>
      value.isFinite ? value.toStringAsFixed(6) : '0';

  /// Escapes the five XML predefined entities.
  static String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
