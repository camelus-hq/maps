import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/transit.dart';

/// Lenient mapper from a MOTIS/Transitous `/stop` response to a domain
/// [TransitStopInfo] (the stop's metadata plus the lines serving it).
///
/// External JSON is hostile (AGENTS.md "Never crash"): every field is
/// type-checked, unknown values are dropped, the collections and strings are
/// bounded, and a malformed route is skipped rather than throwing.
abstract final class MotisStopDto {
  static const int _maxRoutes = 200;
  static const int _maxNameLength = 200;
  static const int _maxLineLength = 60;

  /// Maps the response body to a [TransitStopInfo], or `null` when the payload
  /// carries no usable stop.
  static TransitStopInfo? stopInfoFromResponse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final TransitStopInfo? info = _place(raw['place']);
    if (info == null) {
      return null;
    }
    final Object? rawRoutes = raw['routes'];
    if (rawRoutes is! List) {
      return info;
    }
    final Map<String, TransitStopRoute> byKey = <String, TransitStopRoute>{};
    for (final Object? entry in rawRoutes) {
      if (byKey.length >= _maxRoutes) {
        break;
      }
      final TransitStopRoute? route = _route(entry);
      if (route != null) {
        byKey.putIfAbsent(route.key, () => route);
      }
    }
    return TransitStopInfo(
      stopId: info.stopId,
      name: info.name,
      position: info.position,
      routes: List<TransitStopRoute>.unmodifiable(byKey.values),
    );
  }

  static TransitStopInfo? _place(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final String? stopId = _string(raw['stopId'], _maxNameLength * 2);
    final String? name = _string(raw['name'], _maxNameLength);
    // A radius query returns a synthetic anchor with no id; the routes are
    // still useful, so accept it with a name instead of dropping everything.
    if (stopId == null && name == null) {
      return null;
    }
    return TransitStopInfo(
      stopId: stopId ?? '',
      name: name ?? stopId ?? 'Stop',
      position: LatLon.tryParse(raw['lat'], raw['lon']),
    );
  }

  static TransitStopRoute? _route(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final String? short = _string(raw['routeShortName'], _maxLineLength);
    final String? long = _string(raw['routeLongName'], _maxLineLength * 2);
    final String? routeId = _string(raw['routeId'], _maxNameLength * 2);
    // A route with no label and no id carries nothing useful.
    if (short == null && long == null && routeId == null) {
      return null;
    }
    return TransitStopRoute(
      mode: transitModeFromMotis(raw['mode']),
      routeId: routeId,
      routeShortName: short,
      routeLongName: long,
      agencyName: _string(raw['agencyName'], _maxNameLength),
      routeColor: _color(raw['routeColor']),
      routeTextColor: _color(raw['routeTextColor']),
    );
  }

  /// MOTIS returns a bare hex RGB/RGBA string (e.g. `"992746"`); anything else
  /// is ignored.
  static int? _color(Object? raw) {
    if (raw is! String) {
      return null;
    }
    final String hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) {
      return null;
    }
    final int? value = int.tryParse(hex, radix: 16);
    if (value == null) {
      return null;
    }
    return hex.length == 6 ? 0xFF000000 | value : value;
  }

  static String? _string(Object? raw, int maxLength) {
    if (raw is! String) {
      return null;
    }
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed.length > maxLength
        ? trimmed.substring(0, maxLength)
        : trimmed;
  }
}
