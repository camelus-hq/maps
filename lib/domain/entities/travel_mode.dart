/// Supported travel modes.
///
/// `transit` is planned through [TransitRoutingService] (the Transitous/MOTIS
/// adapter) rather than the turn-by-turn [RoutingService], because a
/// public-transport journey is a sequence of legs with transfers, not a single
/// street route.
enum TravelMode {
  drive,
  walk,
  cycle,
  transit;

  /// Whether this mode is planned as a public-transport journey.
  bool get isTransit => this == TravelMode.transit;

  /// The mode that suits a trip whose straight-line (air) distance is [meters].
  ///
  /// Directions open on this default: walking under 2 km, cycling for 2–9 km,
  /// public transport for 9–20 km, and driving at 20 km and over.
  static TravelMode suggestedForDistance(double meters) {
    if (meters < 2000) {
      return TravelMode.walk;
    }
    if (meters < 9000) {
      return TravelMode.cycle;
    }
    if (meters < 20000) {
      return TravelMode.transit;
    }
    return TravelMode.drive;
  }
}
