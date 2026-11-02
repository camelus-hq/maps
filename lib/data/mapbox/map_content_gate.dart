/// Guards calls that mutate the native Mapbox map (annotations, style
/// sources/layers, the location puck).
///
/// The native SDK only knows an annotation manager once the map is attached
/// **and** its style has finished loading. Calling into it earlier — e.g.
/// `PointAnnotationManager.deleteAll()` while the style is still loading —
/// throws on the platform thread and **crashes the app** with
/// `java.lang.Throwable: No manager found with id: 0`. That exception is
/// delivered natively, so Dart's `try`/`catch` cannot intercept it; the only
/// defence is to not make the call.
///
/// This holds the two facts the decision depends on and exposes [isOpen], the
/// single "may I touch the map now?" answer the service checks before every
/// native mutation. Kept here (rather than as loose booleans) so the rule is
/// unit-tested and cannot regress into a release-only first-run crash.
class MapContentGate {
  bool _attached = false;
  bool _styleLoaded = false;

  /// Whether map content may be applied to the native map right now.
  bool get isOpen => _attached && _styleLoaded;

  /// A map instance was attached. A fresh instance has no loaded style yet, so
  /// this always closes the gate until the next [styleLoaded].
  void attached() {
    _attached = true;
    _styleLoaded = false;
  }

  /// The map instance was disposed; the gate closes until the next [attached].
  void detached() {
    _attached = false;
    _styleLoaded = false;
  }

  /// The style finished loading (initial load or after a reload); content may
  /// now be applied.
  void styleLoaded() => _styleLoaded = true;

  /// A style reload started: the old managers/sources/layers are torn down, so
  /// the map must not be touched until the new style is [styleLoaded] again.
  void styleUnloading() => _styleLoaded = false;
}
