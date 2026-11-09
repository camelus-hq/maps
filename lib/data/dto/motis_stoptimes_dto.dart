import '../../domain/entities/transit.dart';

/// Lenient mapper from a MOTIS/Transitous `/stoptimes` response to domain
/// [TransitStopDeparture]s.
///
/// External JSON is hostile (AGENTS.md "Never crash"): every field is
/// type-checked, unknown values are dropped, the collection and strings are
/// bounded, and a malformed entry is skipped rather than throwing.
abstract final class MotisStoptimesDto {
  static const int _maxDepartures = 40;
  static const int _maxNameLength = 200;
  static const int _maxLineLength = 60;

  /// Maps the response body to departures, soonest first as the provider sent
  /// them.
  static List<TransitStopDeparture> departuresFromResponse(Object? raw) {
    if (raw is! Map) {
      return const <TransitStopDeparture>[];
    }
    final Object? rawTimes = raw['stopTimes'];
    if (rawTimes is! List) {
      return const <TransitStopDeparture>[];
    }
    final List<TransitStopDeparture> departures = <TransitStopDeparture>[];
    for (final Object? entry in rawTimes) {
      if (departures.length >= _maxDepartures) {
        break;
      }
      final TransitStopDeparture? departure = _departure(entry);
      if (departure != null) {
        departures.add(departure);
      }
    }
    return List<TransitStopDeparture>.unmodifiable(departures);
  }

  static TransitStopDeparture? _departure(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final Object? rawPlace = raw['place'];
    final Map<Object?, Object?> place = rawPlace is Map
        ? rawPlace
        : const <Object?, Object?>{};
    final DateTime? departure =
        _time(place['departure']) ?? _time(place['scheduledDeparture']);
    if (departure == null) {
      return null;
    }
    return TransitStopDeparture(
      mode: transitModeFromMotis(raw['mode']),
      departure: departure,
      scheduledDeparture: _time(place['scheduledDeparture']),
      headsign: _string(raw['headsign'], _maxNameLength),
      direction: _string(raw['direction'], _maxNameLength),
      track: _string(place['track'], _maxLineLength),
      scheduledTrack: _string(place['scheduledTrack'], _maxLineLength),
      routeShortName: _string(raw['routeShortName'], _maxLineLength),
      routeLongName: _string(raw['routeLongName'], _maxLineLength * 2),
      tripId: _string(raw['tripId'], _maxNameLength * 2),
      agencyName: _string(raw['agencyName'], _maxNameLength),
      routeColor: _color(raw['routeColor']),
      routeTextColor: _color(raw['routeTextColor']),
      realTime: raw['realTime'] == true,
      cancelled: raw['cancelled'] == true || raw['tripCancelled'] == true,
      wheelchairAccessible: raw['wheelchairAccessible'] == 'ACCESSIBLE',
      bikesAllowed: raw['bikesAllowed'] == true,
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
}
