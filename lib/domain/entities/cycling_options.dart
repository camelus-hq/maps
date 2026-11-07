/// Which kind of bicycle is being ridden — Valhalla's `bicycle_type`.
///
/// The choice changes the whole cost model: a road bike prefers smooth, fast
/// roads, a mountain bike tolerates rough surfaces and does not avoid a climb.
enum BicycleType {
  road,
  hybrid,
  cross,
  mountain;

  /// The label shown in the picker.
  String get label => switch (this) {
    BicycleType.road => 'Road',
    BicycleType.hybrid => 'Hybrid',
    BicycleType.cross => 'Cross',
    BicycleType.mountain => 'Mountain',
  };

  /// Valhalla's default cruising speed (km/h) for this bicycle type on smooth,
  /// flat roads: road 25, cross 20, hybrid 18, mountain 16.
  double get defaultSpeed => switch (this) {
    BicycleType.road => 25,
    BicycleType.cross => 20,
    BicycleType.hybrid => 18,
    BicycleType.mountain => 16,
  };

  /// Parses a user/command value, tolerating case. Unknown values fall back to
  /// [BicycleType.hybrid], which is also Valhalla's default, so a bad value can
  /// never disable routing.
  static BicycleType parse(Object? raw) {
    if (raw is! String) {
      return BicycleType.hybrid;
    }
    return switch (raw.trim().toLowerCase()) {
      'road' => BicycleType.road,
      'cross' => BicycleType.cross,
      'mountain' || 'mtb' => BicycleType.mountain,
      _ => BicycleType.hybrid,
    };
  }
}

/// The Valhalla bicycle costing options exposed under the Cycle travel mode.
///
/// The defaults mirror Valhalla's own, and only options the rider actually
/// changed are sent ([changedOptions]) — so an untouched panel leaves routing
/// exactly as it was before the options existed, and picking a bicycle type
/// keeps Valhalla's type-specific default cruising speed ([cyclingSpeed] stays
/// `null` until the rider overrides it).
class CyclingOptions {
  const CyclingOptions({
    this.bicycleType = BicycleType.hybrid,
    this.useHills = neutralWeight,
    this.avoidBadSurfaces = neutralWeight,
    this.cyclingSpeed,
    this.useRoads = neutralWeight,
    this.avoidEdges = false,
  });

  /// The provider's own defaults (hybrid bicycle).
  static const CyclingOptions defaults = CyclingOptions();

  /// Valhalla's default `use_hills`, `use_roads` and `avoid_bad_surfaces`.
  static const double neutralWeight = 0.25;

  /// The kind of bicycle being ridden (`bicycle_type`).
  final BicycleType bicycleType;

  /// Hills weighting: `0` avoids hills, `1` prefers them (`use_hills`).
  final double useHills;

  /// Rough-surface weighting: `0` tolerates bad surfaces, `1` avoids them
  /// (`avoid_bad_surfaces`).
  final double avoidBadSurfaces;

  /// An explicit cruising speed in km/h (`cycling_speed`), or `null` to use
  /// Valhalla's default for [bicycleType] ([BicycleType.defaultSpeed]).
  final double? cyclingSpeed;

  /// Road weighting: `0` prefers paths and cycleways, `1` prefers roads cars
  /// can use (`use_roads`).
  final double useRoads;

  /// Avoid edges — dead-end roads connected to the network at only one end
  /// (`avoid_edges`).
  final bool avoidEdges;

  /// The cruising speed actually used: the explicit [cyclingSpeed] or the
  /// chosen bicycle's default, clamped to Valhalla's accepted range
  /// (5…60 km/h).
  double get effectiveCyclingSpeed =>
      (cyclingSpeed ?? bicycleType.defaultSpeed).clamp(5, 60);

  CyclingOptions copyWith({
    BicycleType? bicycleType,
    double? useHills,
    double? avoidBadSurfaces,
    double? cyclingSpeed,
    double? useRoads,
    bool? avoidEdges,
    bool clearCyclingSpeed = false,
  }) => CyclingOptions(
    bicycleType: bicycleType ?? this.bicycleType,
    useHills: useHills ?? this.useHills,
    avoidBadSurfaces: avoidBadSurfaces ?? this.avoidBadSurfaces,
    cyclingSpeed: clearCyclingSpeed
        ? null
        : (cyclingSpeed ?? this.cyclingSpeed),
    useRoads: useRoads ?? this.useRoads,
    avoidEdges: avoidEdges ?? this.avoidEdges,
  );

  /// The full effective option set — what the UI shows and the form a control
  /// channel caller reads back.
  Map<String, Object?> toJson() => <String, Object?>{
    'bicycle_type': bicycleType.name,
    'use_hills': useHills.clamp(0, 1),
    'avoid_bad_surfaces': avoidBadSurfaces.clamp(0, 1),
    'cycling_speed': effectiveCyclingSpeed,
    'use_roads': useRoads.clamp(0, 1),
    'avoid_edges': avoidEdges,
  };

  /// The `costing_options.bicycle` overrides Valhalla should apply: only the
  /// options that differ from Valhalla's defaults. Empty when the panel is
  /// untouched, so the request is unchanged. Weights are clamped so a hostile
  /// command value can never produce a nonsensical request.
  Map<String, Object?> changedOptions() {
    final Map<String, Object?> out = <String, Object?>{};
    if (bicycleType != BicycleType.hybrid) {
      out['bicycle_type'] = bicycleType.name;
    }
    if (useHills != neutralWeight) {
      out['use_hills'] = useHills.clamp(0, 1);
    }
    if (avoidBadSurfaces != neutralWeight) {
      out['avoid_bad_surfaces'] = avoidBadSurfaces.clamp(0, 1);
    }
    final double? speed = cyclingSpeed;
    if (speed != null && effectiveCyclingSpeed != bicycleType.defaultSpeed) {
      out['cycling_speed'] = effectiveCyclingSpeed;
    }
    if (useRoads != neutralWeight) {
      out['use_roads'] = useRoads.clamp(0, 1);
    }
    if (avoidEdges) {
      out['avoid_edges'] = true;
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is CyclingOptions &&
      other.bicycleType == bicycleType &&
      other.useHills == useHills &&
      other.avoidBadSurfaces == avoidBadSurfaces &&
      other.cyclingSpeed == cyclingSpeed &&
      other.useRoads == useRoads &&
      other.avoidEdges == avoidEdges;

  @override
  int get hashCode => Object.hash(
    bicycleType,
    useHills,
    avoidBadSurfaces,
    cyclingSpeed,
    useRoads,
    avoidEdges,
  );
}
