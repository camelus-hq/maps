import '../../domain/entities/lat_lon.dart';
import '../../domain/entities/transit.dart';
import '../valhalla/polyline_codec.dart';

/// Lenient mapper from a MOTIS/Transitous `/plan` response to domain
/// [TransitItinerary]s.
///
/// External JSON is hostile: every field is type-checked, unknown values are
/// dropped, collections and strings are bounded, and a malformed itinerary is
/// skipped rather than throwing. Nothing here can crash the app (AGENTS.md
/// "Never crash").
abstract final class MotisPlanDto {
  /// Hard caps so a hostile/oversized payload cannot exhaust memory.
  static const int _maxItineraries = 20;
  static const int _maxLegsPerItinerary = 100;
  static const int _maxIntermediateStops = 500;
  static const int _maxEncodedGeometry = 200000;
  static const int _maxNameLength = 200;
  static const int _maxLineLength = 60;

  /// Maps the response body to itineraries (best first, as the provider sent
  /// them).
  static List<TransitItinerary> itinerariesFromResponse(Object? raw) {
    if (raw is! Map) {
      return const <TransitItinerary>[];
    }
    final Object? rawItineraries = raw['itineraries'];
    if (rawItineraries is! List) {
      return const <TransitItinerary>[];
    }
    final List<TransitItinerary> itineraries = <TransitItinerary>[];
    for (final Object? entry in rawItineraries) {
      if (itineraries.length >= _maxItineraries) {
        break;
      }
      final TransitItinerary? itinerary = _itinerary(entry);
      if (itinerary != null) {
        itineraries.add(itinerary);
      }
    }
    return List<TransitItinerary>.unmodifiable(itineraries);
  }

  /// Maps a single `/trip` response (an [Itinerary] object, not wrapped in an
  /// `itineraries` list) to a domain [TransitItinerary], or `null` when the
  /// payload carries no usable legs.
  static TransitItinerary? itineraryFromResponse(Object? raw) =>
      _itinerary(raw);

  static TransitItinerary? _itinerary(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? rawLegs = raw['legs'];
    if (rawLegs is! List || rawLegs.isEmpty) {
      return null;
    }
    final List<TransitLeg> legs = <TransitLeg>[];
    for (final Object? entry in rawLegs) {
      if (legs.length >= _maxLegsPerItinerary) {
        break;
      }
      final TransitLeg? leg = _leg(entry);
      if (leg != null) {
        legs.add(leg);
      }
    }
    if (legs.isEmpty) {
      return null;
    }
    return TransitItinerary(
      id: _string(raw['id'], 4096),
      startTime: _time(raw['startTime']) ?? legs.first.startTime,
      endTime: _time(raw['endTime']) ?? legs.last.endTime,
      legs: List<TransitLeg>.unmodifiable(legs),
    );
  }

  static TransitLeg? _leg(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final TransitStop? from = _stop(raw['from']);
    final TransitStop? to = _stop(raw['to']);
    final DateTime? start = _time(raw['startTime']);
    final DateTime? end = _time(raw['endTime']);
    if (from == null || to == null || start == null || end == null) {
      return null;
    }
    final int seconds =
        _int(raw['duration']) ?? end.difference(start).inSeconds;
    return TransitLeg(
      mode: transitModeFromMotis(raw['mode']),
      from: from,
      to: to,
      startTime: start,
      endTime: end,
      duration: Duration(seconds: seconds < 0 ? 0 : seconds),
      distanceMeters: _double(raw['distance']) ?? 0,
      geometry: _geometry(raw['legGeometry']),
      intermediateStops: _stops(raw['intermediateStops']),
      routeShortName: _string(raw['routeShortName'], _maxLineLength),
      routeLongName: _string(raw['routeLongName'], _maxLineLength * 2),
      headsign: _string(raw['headsign'], _maxNameLength),
      agencyName: _string(raw['agencyName'], _maxNameLength),
      routeColor: _color(raw['routeColor']),
      routeTextColor: _color(raw['routeTextColor']),
      realTime: raw['realTime'] == true,
      cancelled: raw['cancelled'] == true,
      scheduledStartTime: _time(raw['scheduledStartTime']),
      scheduledEndTime: _time(raw['scheduledEndTime']),
      tripId: _string(raw['tripId'], _maxNameLength * 2),
    );
  }

  static List<TransitStop> _stops(Object? raw) {
    if (raw is! List || raw.isEmpty) {
      return const <TransitStop>[];
    }
    final List<TransitStop> stops = <TransitStop>[];
    for (final Object? entry in raw) {
      if (stops.length >= _maxIntermediateStops) {
        break;
      }
      final TransitStop? stop = _stop(entry);
      if (stop != null) {
        stops.add(stop);
      }
    }
    return List<TransitStop>.unmodifiable(stops);
  }

  static TransitStop? _stop(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final String? name = _string(raw['name'], _maxNameLength);
    final LatLon? position = LatLon.tryParse(raw['lat'], raw['lon']);
    // A stop with neither a name nor a coordinate carries nothing useful.
    if (name == null && position == null) {
      return null;
    }
    return TransitStop(
      name: name ?? 'Stop',
      id: _string(raw['stopId'], _maxNameLength),
      position: position,
      track: _string(raw['track'], _maxLineLength),
      scheduledTrack: _string(raw['scheduledTrack'], _maxLineLength),
      arrival: _time(raw['arrival']) ?? _time(raw['scheduledArrival']),
      departure: _time(raw['departure']) ?? _time(raw['scheduledDeparture']),
      cancelled: raw['cancelled'] == true,
    );
  }

  /// Decodes a MOTIS encoded polyline (`legGeometry`), bounded and hostile-safe.
  static List<LatLon> _geometry(Object? raw) {
    if (raw is! Map) {
      return const <LatLon>[];
    }
    final String? points = _string(raw['points'], _maxEncodedGeometry);
    if (points == null) {
      return const <LatLon>[];
    }
    final int precision = _int(raw['precision']) ?? 7;
    if (precision < 1 || precision > 9) {
      return const <LatLon>[];
    }
    return decodePolyline(points, precision: precision);
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

  static DateTime? _time(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw.trim())?.toUtc();
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

  static int? _int(Object? raw) => switch (raw) {
    final int value => value,
    final double value => value.isFinite ? value.toInt() : null,
    _ => null,
  };

  static double? _double(Object? raw) => switch (raw) {
    final double value => value.isFinite ? value : null,
    final int value => value.toDouble(),
    _ => null,
  };
}
