import 'package:flutter_test/flutter_test.dart';
import 'package:openmaps/data/mapbox/map_content_gate.dart';

/// Regression guard for the release-only first-run crash: Mapbox annotation
/// managers may only be touched once the map is attached AND its style has
/// loaded. Calling earlier (`PointAnnotationManager.deleteAll()` before the
/// style is ready) throws natively — `java.lang.Throwable: No manager found
/// with id: 0` — and kills the app; Dart cannot catch it. The gate is the single
/// rule the service checks before every native mutation, so this keeps the
/// ordering honest.
void main() {
  group('MapContentGate', () {
    test('starts closed', () {
      expect(MapContentGate().isOpen, isFalse);
    });

    test('opens only when attached and the style is loaded', () {
      final MapContentGate gate = MapContentGate();

      gate.attached();
      expect(gate.isOpen, isFalse, reason: 'attached without a style');

      gate.styleLoaded();
      expect(gate.isOpen, isTrue);
    });

    test('a style load that precedes attach does not open the gate', () {
      final MapContentGate gate = MapContentGate();

      // The style-loaded event can fire before onMapCreated.
      gate.styleLoaded();
      expect(gate.isOpen, isFalse);

      // Attaching a fresh map has no loaded style yet.
      gate.attached();
      expect(gate.isOpen, isFalse);

      gate.styleLoaded();
      expect(gate.isOpen, isTrue);
    });

    test('a style reload closes the gate until the new style loads', () {
      final MapContentGate gate = MapContentGate()
        ..attached()
        ..styleLoaded();
      expect(gate.isOpen, isTrue);

      gate.styleUnloading();
      expect(gate.isOpen, isFalse, reason: 'must not touch a reloading style');

      gate.styleLoaded();
      expect(gate.isOpen, isTrue);
    });

    test('detaching closes the gate', () {
      final MapContentGate gate = MapContentGate()
        ..attached()
        ..styleLoaded();

      gate.detached();
      expect(gate.isOpen, isFalse);
    });
  });
}
