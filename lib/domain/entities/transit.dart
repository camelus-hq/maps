import '../../core/utils/format.dart';
import 'lat_lon.dart';
import 'route.dart';

/// A public-transport or street mode.
///
/// The vocabulary mirrors the MOTIS/Transitous `mode` field (the value that
/// travels over the wire) so an adapter can round-trip it; the display label is
/// ours. Provider-specific spellings are folded by [transitModeFromMotis], and
/// anything unrecognised degrades to [TransitMode.other] rather than throwing.
enum TransitMode {
  walk,
  bike,
  car,
  bus,
  coach,
  regionalBus,
  trolleybus,
  tram,
  subway,
  metro,
  rail,
  regionalRail,
  highSpeedRail,
  longDistanceRail,
  nightRail,
  suburbanRail,
  ferry,
  cableCar,
  aerialLift,
  funicular,
  monorail,
  other;

  /// The MOTIS mode name for this mode (used in `transitModes`/`directModes`).
  String get motisName => switch (this) {
    TransitMode.walk => 'WALK',
    TransitMode.bike => 'BIKE',
    TransitMode.car => 'CAR',
    TransitMode.bus => 'BUS',
    TransitMode.coach => 'COACH',
    TransitMode.regionalBus => 'REGIONAL_BUS',
    TransitMode.trolleybus => 'TROLLEYBUS',
    TransitMode.tram => 'TRAM',
    TransitMode.subway => 'SUBWAY',
    TransitMode.metro => 'METRO',
    TransitMode.rail => 'RAIL',
    TransitMode.regionalRail => 'REGIONAL_RAIL',
    TransitMode.highSpeedRail => 'HIGHSPEED_RAIL',
    TransitMode.longDistanceRail => 'LONG_DISTANCE',
    TransitMode.nightRail => 'NIGHT_RAIL',
    TransitMode.suburbanRail => 'SUBURBAN',
    TransitMode.ferry => 'FERRY',
    TransitMode.cableCar => 'CABLE_CAR',
    TransitMode.aerialLift => 'AERIAL_LIFT',
    TransitMode.funicular => 'FUNICULAR',
    TransitMode.monorail => 'MONORAIL',
    TransitMode.other => 'OTHER',
  };

  /// A short human label ("Walk", "Bus", "S-Bahn").
  String get label => switch (this) {
    TransitMode.walk => 'Walk',
    TransitMode.bike => 'Bike',
    TransitMode.car => 'Car',
    TransitMode.bus || TransitMode.regionalBus => 'Bus',
    TransitMode.coach => 'Coach',
    TransitMode.trolleybus => 'Trolleybus',
    TransitMode.tram => 'Tram',
    TransitMode.subway || TransitMode.metro => 'Subway',
    TransitMode.rail => 'Train',
    TransitMode.regionalRail => 'Regional train',
    TransitMode.highSpeedRail => 'High-speed train',
    TransitMode.longDistanceRail => 'Long-distance train',
    TransitMode.nightRail => 'Night train',
    TransitMode.suburbanRail => 'Suburban train',
    TransitMode.ferry => 'Ferry',
    TransitMode.cableCar => 'Cable car',
    TransitMode.aerialLift => 'Aerial lift',
    TransitMode.funicular => 'Funicular',
    TransitMode.monorail => 'Monorail',
    TransitMode.other => 'Transit',
  };

  /// Whether this is a street mode (walk/bike/car) rather than a transit leg.
  bool get isStreet =>
      this == TransitMode.walk ||
      this == TransitMode.bike ||
      this == TransitMode.car;
}

/// A quick preference filter over [TransitMode] (the "Prefer" chips).
enum TransitModeGroup {
  bus,
  tram,
  subway,
  train,
  ferry;

  String get label => switch (this) {
    TransitModeGroup.bus => 'Bus',
    TransitModeGroup.tram => 'Tram',
    TransitModeGroup.subway => 'Subway',
    TransitModeGroup.train => 'Train',
    TransitModeGroup.ferry => 'Ferry',
  };

  /// The MOTIS modes that belong to this group.
  List<TransitMode> get modes => switch (this) {
    TransitModeGroup.bus => const <TransitMode>[
      TransitMode.bus,
      TransitMode.coach,
      TransitMode.regionalBus,
      TransitMode.trolleybus,
    ],
    TransitModeGroup.tram => const <TransitMode>[TransitMode.tram],
    TransitModeGroup.subway => const <TransitMode>[
      TransitMode.subway,
      TransitMode.metro,
    ],
    TransitModeGroup.train => const <TransitMode>[
      TransitMode.rail,
      TransitMode.regionalRail,
      TransitMode.highSpeedRail,
      TransitMode.longDistanceRail,
      TransitMode.nightRail,
      TransitMode.suburbanRail,
    ],
    TransitModeGroup.ferry => const <TransitMode>[TransitMode.ferry],
  };
}

/// Maps a MOTIS `mode` string to a [TransitMode]; unknown values degrade to
/// [TransitMode.other].
TransitMode transitModeFromMotis(Object? raw) {
  if (raw is! String) {
    return TransitMode.other;
  }
  return switch (raw.trim().toUpperCase()) {
    'WALK' => TransitMode.walk,
    'BIKE' || 'BICYCLE' => TransitMode.bike,
    'CAR' || 'AUTO' => TransitMode.car,
    'BUS' => TransitMode.bus,
    'COACH' => TransitMode.coach,
    'REGIONAL_BUS' || 'REGIONALBUS' => TransitMode.regionalBus,
    'TROLLEYBUS' => TransitMode.trolleybus,
    'TRAM' => TransitMode.tram,
    'SUBWAY' => TransitMode.subway,
    'METRO' => TransitMode.metro,
    'RAIL' => TransitMode.rail,
    'REGIONAL_RAIL' || 'REGIONALRAIL' => TransitMode.regionalRail,
    'HIGHSPEED_RAIL' || 'HIGHSPEEDRAIL' => TransitMode.highSpeedRail,
    'LONG_DISTANCE' || 'LONGDISTANCE' => TransitMode.longDistanceRail,
    'NIGHT_RAIL' || 'NIGHTRAIL' => TransitMode.nightRail,
    'SUBURBAN' => TransitMode.suburbanRail,
    'FERRY' => TransitMode.ferry,
    'CABLE_CAR' || 'CABLECAR' => TransitMode.cableCar,
    'AERIAL_LIFT' || 'AERIALLIFT' => TransitMode.aerialLift,
    'FUNICULAR' => TransitMode.funicular,
    'MONORAIL' => TransitMode.monorail,
    _ => TransitMode.other,
  };
}

/// When a transit journey should depart or arrive.
enum TransitTimeMode { leaveNow, departAt, arriveBy }

/// A stop, station or coordinate where a leg begins or ends.
class TransitStop {
  const TransitStop({
    required this.name,
    this.id,
    this.position,
    this.track,
    this.scheduledTrack,
    this.cancelled = false,
  });

  final String name;

  /// The provider's stop id (MOTIS `stopId`), when this is a real stop.
  final String? id;

  /// Present for transit legs; may be absent for a plain coordinate.
  final LatLon? position;

  /// The platform/track actually used (realtime), when the provider knows it.
  final String? track;

  /// The planned platform/track.
  final String? scheduledTrack;

  final bool cancelled;

  /// The track to show: the live one when known, else the scheduled one.
  String? get displayTrack => track ?? scheduledTrack;

  /// Whether a track/platform is worth showing at this stop.
  bool get hasTrack {
    final String? value = displayTrack;
    return value != null && value.trim().isNotEmpty;
  }
}

/// One leg of a [TransitItinerary]: a street walk/bike/car leg or a ride on a
/// single line between two stops.
class TransitLeg {
  const TransitLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.distanceMeters = 0,
    this.geometry = const <LatLon>[],
    this.intermediateStops = const <TransitStop>[],
    this.routeShortName,
    this.routeLongName,
    this.headsign,
    this.agencyName,
    this.routeColor,
    this.routeTextColor,
    this.realTime = false,
    this.cancelled = false,
    this.scheduledStartTime,
    this.scheduledEndTime,
    this.tripId,
  });

  final TransitMode mode;
  final TransitStop from;
  final TransitStop to;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final double distanceMeters;
  final List<LatLon> geometry;

  /// Stops passed through without a change of vehicle.
  final List<TransitStop> intermediateStops;

  /// The line's short name as shown on the vehicle (e.g. "U7", "S1").
  final String? routeShortName;
  final String? routeLongName;
  final String? headsign;
  final String? agencyName;

  /// The operator's line colour / text colour as ARGB, when provided.
  final int? routeColor;
  final int? routeTextColor;

  /// Whether the times came from a realtime feed.
  final bool realTime;
  final bool cancelled;

  /// The planned times, so the UI can show a delay.
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;

  final String? tripId;

  /// A transit ride (bus/tram/train/…) as opposed to a street leg.
  bool get isTransit =>
      !mode.isStreet &&
      (mode != TransitMode.other || (routeShortName ?? tripId) != null);

  bool get isWalk => mode == TransitMode.walk;

  /// The label drawn on the line badge ("U7", "Bus 100", …).
  String get lineLabel {
    final String? short = _nonEmpty(routeShortName);
    if (short != null) {
      return short;
    }
    final String? long = _nonEmpty(routeLongName);
    return long ?? mode.label;
  }

  /// The line colour to draw and to fill the badge with: the operator's own
  /// colour when the provider reported one, else our mode fallback.
  int get displayColor => routeColor ?? transitModeColor(mode);

  /// How late (positive) or early (negative) the ride actually starts, when the
  /// provider gave both a scheduled and a realtime time.
  Duration? get departureDelay {
    final DateTime? scheduled = scheduledStartTime;
    if (scheduled == null || !realTime) {
      return null;
    }
    return startTime.difference(scheduled);
  }

  /// How late (positive) or early (negative) the ride arrives.
  Duration? get arrivalDelay {
    final DateTime? scheduled = scheduledEndTime;
    if (scheduled == null || !realTime) {
      return null;
    }
    return endTime.difference(scheduled);
  }
}

/// A complete door-to-door journey: one or more [TransitLeg]s in order.
class TransitItinerary {
  const TransitItinerary({
    required this.legs,
    required this.startTime,
    required this.endTime,
    this.id,
  });

  final List<TransitLeg> legs;
  final DateTime startTime;
  final DateTime endTime;
  final String? id;

  Duration get duration => endTime.difference(startTime);

  /// Every leg ridden on a vehicle.
  List<TransitLeg> get transitLegs => <TransitLeg>[
    for (final TransitLeg leg in legs)
      if (leg.isTransit) leg,
  ];

  /// The number of changes between transit legs.
  int get transfers {
    final int rides = transitLegs.length;
    return rides <= 1 ? 0 : rides - 1;
  }

  /// The concatenated geometry of every leg, in order (for the map line).
  List<LatLon> get geometry => <LatLon>[
    for (final TransitLeg leg in legs) ...leg.geometry,
  ];

  /// Total distance walked as part of the journey.
  double get walkingMeters {
    double total = 0;
    for (final TransitLeg leg in legs) {
      if (leg.isWalk) {
        total += leg.distanceMeters;
      }
    }
    return total;
  }

  /// True while any ride has a realtime update.
  bool get hasRealtime {
    for (final TransitLeg leg in legs) {
      if (leg.isTransit && leg.realTime) {
        return true;
      }
    }
    return false;
  }

  /// True if any ride is cancelled.
  bool get isCancelled {
    for (final TransitLeg leg in legs) {
      if (leg.cancelled) {
        return true;
      }
    }
    return false;
  }

  /// The delay of the first ride, when it is running late or early.
  Duration? get departureDelay {
    for (final TransitLeg leg in legs) {
      if (leg.isTransit) {
        return leg.departureDelay;
      }
    }
    return null;
  }

  /// The delay of the last ride.
  Duration? get arrivalDelay {
    for (final TransitLeg leg in legs) {
      if (leg.isTransit) {
        final Duration? delay = leg.arrivalDelay;
        if (delay != null) {
          return delay;
        }
      }
    }
    return null;
  }

  /// The operators of the rides, de-duplicated and in order.
  List<String> get agencies {
    final List<String> names = <String>[];
    for (final TransitLeg leg in legs) {
      final String? name = _nonEmpty(leg.agencyName);
      if (name != null && !names.contains(name)) {
        names.add(name);
      }
    }
    return names;
  }

  /// The distinct transit rides, for the compact line badges on a card.
  List<TransitLeg> get rides => transitLegs;

  /// Projects the journey onto the street [Route] model so the existing
  /// guidance UI can follow it: one [Leg] per leg, with a single maneuver
  /// describing what happens ("Walk 3 min to …", "Board U7 to …"), and a final
  /// arrival maneuver.
  Route toRoute() {
    final List<Leg> routeLegs = <Leg>[];
    final List<LatLon> line = <LatLon>[];
    for (final TransitLeg leg in legs) {
      line.addAll(leg.geometry);
      routeLegs.add(
        Leg(
          maneuvers: <Maneuver>[
            Maneuver(
              instruction: leg.isTransit
                  ? 'Board ${leg.lineLabel} to ${_nonEmpty(leg.headsign) ?? leg.to.name}'
                  : '${leg.mode.label} ${formatDuration(leg.duration)} to ${leg.to.name}',
              type: ManeuverType.straight,
              distanceMeters: leg.distanceMeters,
            ),
          ],
          distanceMeters: leg.distanceMeters,
          duration: leg.duration,
        ),
      );
    }
    if (legs.isNotEmpty) {
      routeLegs.add(
        Leg(
          maneuvers: <Maneuver>[
            Maneuver(
              instruction: 'Arrive at ${legs.last.to.name}',
              type: ManeuverType.arrive,
            ),
          ],
          distanceMeters: 0,
          duration: Duration.zero,
        ),
      );
    }
    double distance = 0;
    for (final Leg leg in routeLegs) {
      distance += leg.distanceMeters;
    }
    return Route(
      legs: List<Leg>.unmodifiable(routeLegs),
      distanceMeters: distance,
      duration: duration,
      geometry: List<LatLon>.unmodifiable(line),
    );
  }

  /// The time spent waiting at a stop before the [index]-th leg departs: the
  /// gap between the previous leg's arrival and this leg's departure. Zero at
  /// the journey's start and for back-to-back legs.
  Duration waitBefore(int index) {
    if (index <= 0 || index >= legs.length) {
      return Duration.zero;
    }
    final Duration gap = legs[index].startTime.difference(
      legs[index - 1].endTime,
    );
    return gap.isNegative ? Duration.zero : gap;
  }

  /// The origin stop of the first leg.
  TransitStop? get originStop => legs.isEmpty ? null : legs.first.from;

  /// The destination stop of the last leg.
  TransitStop? get destinationStop => legs.isEmpty ? null : legs.last.to;

  /// Where the traveller is after covering [traveledMeters] along the
  /// journey's concatenated [geometry] (the same geometry the guidance uses to
  /// project a position). Never throws: an empty or zero-length journey reads
  /// as [TransitPhase.arrived].
  TransitProgress progressAt(double traveledMeters) {
    if (legs.isEmpty) {
      return TransitProgress.arrived;
    }
    final List<double> starts = <double>[];
    final List<double> ends = <double>[];
    double cursor = 0;
    for (final TransitLeg leg in legs) {
      starts.add(cursor);
      cursor += _geometryLength(leg.geometry);
      ends.add(cursor);
    }
    final double total = cursor;
    final double traveled = traveledMeters.isFinite
        ? traveledMeters.clamp(0, total)
        : 0;
    if (total <= 0 || traveled >= total) {
      return TransitProgress(
        phase: TransitPhase.arrived,
        legIndex: legs.length - 1,
      );
    }
    int index = 0;
    // A position exactly on a leg boundary belongs to the *later* leg, so a
    // traveller standing at the boarding stop already reads as "on board"
    // rather than still walking.
    while (index < legs.length - 1 && traveled >= ends[index]) {
      index++;
    }
    final TransitLeg leg = legs[index];
    final double span = ends[index] - starts[index];
    final double remaining = (ends[index] - traveled).clamp(0, double.infinity);
    final double fraction = span <= 0
        ? 0
        : ((traveled - starts[index]) / span).clamp(0, 1);
    if (leg.isTransit) {
      return TransitProgress(
        phase: TransitPhase.ride,
        legIndex: index,
        ride: leg,
        rideLegIndex: index,
        stopsRemaining: _stopsRemaining(
          leg,
          traveled - starts[index],
          fraction,
        ),
        remainingInLeg: remaining,
        fractionInLeg: fraction,
      );
    }
    final int? nextRide = _nextTransitIndex(index);
    return TransitProgress(
      phase: TransitPhase.walk,
      legIndex: index,
      ride: nextRide == null ? null : legs[nextRide],
      rideLegIndex: nextRide,
      remainingInLeg: remaining,
      fractionInLeg: fraction,
    );
  }

  /// The index of the next ride after [index] (walking toward it), or `null`
  /// when only a final walk to the destination remains.
  int? _nextTransitIndex(int index) {
    for (int i = index + 1; i < legs.length; i++) {
      if (legs[i].isTransit) {
        return i;
      }
    }
    return null;
  }

  /// How many stops are left before alighting from [leg], given the distance
  /// already covered inside it (the alight stop counts as one). Uses the
  /// intermediate stops' coordinates when the provider gave them, and falls
  /// back to the ride's progress fraction otherwise.
  int _stopsRemaining(TransitLeg leg, double traveledInLeg, double fraction) {
    final List<TransitStop> stops = leg.intermediateStops;
    final List<LatLon> line = leg.geometry;
    if (line.length >= 2 && stops.isNotEmpty) {
      final List<double> cumulative = <double>[0];
      for (int i = 1; i < line.length; i++) {
        cumulative.add(cumulative[i - 1] + line[i - 1].distanceTo(line[i]));
      }
      int remaining = 0;
      for (final TransitStop stop in stops) {
        final LatLon? position = stop.position;
        if (position == null) {
          remaining++;
          continue;
        }
        double best = double.infinity;
        int bestIndex = 0;
        for (int i = 0; i < line.length; i++) {
          final double distance = line[i].distanceTo(position);
          if (distance < best) {
            best = distance;
            bestIndex = i;
          }
        }
        if (cumulative[bestIndex] > traveledInLeg) {
          remaining++;
        }
      }
      // The alight stop itself is one more stop.
      return remaining + 1;
    }
    final int total = stops.length + 1;
    final int left = ((1 - fraction) * total).ceil();
    return left.clamp(1, total);
  }

  static double _geometryLength(List<LatLon> geometry) {
    double total = 0;
    for (int i = 1; i < geometry.length; i++) {
      total += geometry[i - 1].distanceTo(geometry[i]);
    }
    return total;
  }
}

/// The phase of a public-transport journey the traveller is currently in.
enum TransitPhase {
  /// On foot toward the next boarding stop (or the final destination).
  walk,

  /// Standing at a stop waiting to board the next ride.
  board,

  /// On board a vehicle.
  ride,

  /// The journey is complete.
  arrived,
}

/// Where the traveller is within a [TransitItinerary], derived from the
/// distance covered along the journey's geometry. Pure data — the UI turns it
/// into the top card and the live timeline indicator.
class TransitProgress {
  const TransitProgress({
    required this.phase,
    required this.legIndex,
    this.ride,
    this.rideLegIndex,
    this.stopsRemaining = 0,
    this.remainingInLeg = 0,
    this.fractionInLeg = 0,
  });

  final TransitPhase phase;

  /// The leg whose geometry the traveller is on (a walk or a ride).
  final int legIndex;

  /// The ride that governs the current step: the ride being ridden
  /// ([TransitPhase.ride]) or the next one being walked to/boarded.
  final TransitLeg? ride;

  /// The index of [ride] within the itinerary's legs, when known.
  final int? rideLegIndex;

  /// Stops left before alighting the current ride (0 while not riding).
  final int stopsRemaining;

  /// Metres left in the current leg.
  final double remainingInLeg;

  /// How far through the current leg, 0…1.
  final double fractionInLeg;

  /// Whether the traveller is currently on board a vehicle.
  bool get onBoard => phase == TransitPhase.ride;

  /// The completed journey.
  static const TransitProgress arrived = TransitProgress(
    phase: TransitPhase.arrived,
    legIndex: 0,
  );
}

/// A public-transport routing request.
class TransitQuery {
  const TransitQuery({
    required this.origin,
    required this.destination,
    this.stops = const <LatLon>[],
    this.timeMode = TransitTimeMode.leaveNow,
    this.time,
    this.preferredModes = const <TransitMode>{},
    this.fewerTransfers = false,
    this.lessWalking = false,
    this.maxTransfers,
    this.numItineraries = 5,
  });

  final LatLon origin;
  final LatLon destination;

  /// Intermediate stops the journey must pass through, in order.
  final List<LatLon> stops;

  final TransitTimeMode timeMode;

  /// Departure (or arrival) time; `null` means "now".
  final DateTime? time;

  /// The transit modes the traveller prefers; empty means all.
  final Set<TransitMode> preferredModes;

  /// Ask the provider to prioritise fewer changes / less walking.
  final bool fewerTransfers;
  final bool lessWalking;

  /// An upper bound on changes, when the provider supports it.
  final int? maxTransfers;

  final int numItineraries;

  /// Origin first, then any [stops], then the destination.
  List<LatLon> get waypoints => <LatLon>[origin, ...stops, destination];

  /// Whether the traveller asked to arrive (rather than depart) by [time].
  bool get arriveBy => timeMode == TransitTimeMode.arriveBy;
}

String? _nonEmpty(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// The colour used for a walking leg on the map (our own neutral grey).
const int transitWalkColor = 0xFF8A8F98;

/// Our own fallback line colour for a transit mode, used when the provider does
/// not report the operator's own colour. Plain ARGB so the domain stays
/// Flutter-free (the map adapter and the UI share this).
int transitModeColor(TransitMode mode) => switch (mode) {
  TransitMode.bus ||
  TransitMode.regionalBus ||
  TransitMode.coach ||
  TransitMode.trolleybus => 0xFF1F6FB2,
  TransitMode.tram => 0xFFB23A48,
  TransitMode.subway || TransitMode.metro => 0xFF5B4CC4,
  TransitMode.rail ||
  TransitMode.regionalRail ||
  TransitMode.highSpeedRail ||
  TransitMode.longDistanceRail ||
  TransitMode.nightRail ||
  TransitMode.suburbanRail => 0xFF2E7D6B,
  TransitMode.ferry => 0xFF1D6FA5,
  TransitMode.cableCar ||
  TransitMode.aerialLift ||
  TransitMode.funicular ||
  TransitMode.monorail => 0xFF7A5C1E,
  _ => 0xFF4A6B63,
};

/// A request for the next departures from one stop (the "Departures" board).
class TransitDeparturesQuery {
  const TransitDeparturesQuery({
    required this.stopId,
    this.time,
    this.limit = 12,
  });

  /// The provider's stop id (MOTIS `stopId`).
  final String stopId;

  /// Don't return departures before this time; `null` means "now".
  final DateTime? time;

  /// The maximum number of departures to return (bounded by the adapter).
  final int limit;
}

/// One departure from a stop: a line, where it goes, when it leaves and — with
/// a realtime feed — how late it is. The fields mirror what MOTIS `/stoptimes`
/// reports, mapped into the domain's own vocabulary.
class TransitStopDeparture {
  const TransitStopDeparture({
    required this.mode,
    required this.departure,
    this.headsign,
    this.direction,
    this.scheduledDeparture,
    this.track,
    this.scheduledTrack,
    this.routeShortName,
    this.routeLongName,
    this.tripId,
    this.agencyName,
    this.routeColor,
    this.routeTextColor,
    this.realTime = false,
    this.cancelled = false,
    this.wheelchairAccessible = false,
    this.bikesAllowed = false,
  });

  final TransitMode mode;

  /// The scheduled or predicted departure time (UTC).
  final DateTime departure;

  /// The planned departure time, when a realtime one superseded it.
  final DateTime? scheduledDeparture;

  /// Where the trip is headed (its destination), i.e. the "to" name.
  final String? headsign;

  /// A secondary direction description, when the provider gives one.
  final String? direction;

  /// The platform/track actually used (realtime), when known.
  final String? track;

  /// The planned platform/track.
  final String? scheduledTrack;

  final String? routeShortName;
  final String? routeLongName;
  final String? tripId;
  final String? agencyName;
  final int? routeColor;
  final int? routeTextColor;
  final bool realTime;
  final bool cancelled;
  final bool wheelchairAccessible;
  final bool bikesAllowed;

  /// The departure time to show (the live one wins).
  DateTime get displayDeparture => departure;

  /// The track to show: the live one when known, else the scheduled one.
  String? get displayTrack {
    final String? value = (track ?? scheduledTrack)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get hasTrack => displayTrack != null;

  /// How late (positive) or early (negative) the departure is, when the
  /// provider gave both a scheduled and a realtime time.
  Duration? get delay {
    final DateTime? scheduled = scheduledDeparture;
    if (scheduled == null || !realTime) {
      return null;
    }
    return departure.difference(scheduled);
  }

  /// The label drawn on a line badge ("U7", "Bus 100", …).
  String get lineLabel {
    final String? short = _nonEmpty(routeShortName);
    if (short != null) {
      return short;
    }
    return _nonEmpty(routeLongName) ?? mode.label;
  }

  /// The operator's own colour, else our mode fallback.
  int get displayColor => routeColor ?? transitModeColor(mode);
}
