import 'package:flutter/gestures.dart';

/// Injects synthetic pointer events through the gesture binding so the `ui.*`
/// control commands can drive the Flutter UI exactly like a tap or drag
/// (AGENTS.md §Driving the app: no flow may be gesture-only).
///
/// Events are dispatched synchronously in one burst — the same way the widget
/// test framework performs a `drag`, which the gesture recognisers accept
/// reliably. Each call hit-tests and routes normally. Only meaningful while a
/// Flutter view is attached (debug/profile builds with the control channel).
abstract final class SyntheticInput {
  /// Pointer ids for synthetic input start high so they never collide with the
  /// platform's real touch pointers.
  static int _nextPointer = 9000;

  static const int _device = 1;

  static GestureBinding _binding() {
    final GestureBinding binding = GestureBinding.instance;
    // Our synthetic stream carries its own timing; the engine's pointer
    // resampler would drop or re-order it, so disable it while injecting.
    binding.resamplingEnabled = false;
    return binding;
  }

  /// A press-release at logical ([x], [y]).
  static void tap(double x, double y) {
    final GestureBinding binding = _binding();
    final int pointer = _nextPointer++;
    final Offset position = Offset(x, y);
    binding
      ..handlePointerEvent(
        PointerDownEvent(
          pointer: pointer,
          position: position,
          kind: PointerDeviceKind.touch,
          device: _device,
          buttons: kPrimaryButton,
        ),
      )
      ..handlePointerEvent(
        PointerUpEvent(
          pointer: pointer,
          position: position,
          kind: PointerDeviceKind.touch,
          device: _device,
          buttons: kPrimaryButton,
        ),
      );
  }

  /// A press, a sequence of moves, then release — a drag/swipe.
  static void swipe({
    required double fromX,
    required double fromY,
    required double toX,
    required double toY,
    int steps = 12,
  }) {
    final GestureBinding binding = _binding();
    final int pointer = _nextPointer++;
    final Offset from = Offset(fromX, fromY);
    final Offset to = Offset(toX, toY);
    final int safeSteps = steps < 1 ? 1 : steps;

    binding.handlePointerEvent(
      PointerDownEvent(
        pointer: pointer,
        position: from,
        kind: PointerDeviceKind.touch,
        device: _device,
        buttons: kPrimaryButton,
      ),
    );

    Offset previous = from;
    for (int i = 1; i <= safeSteps; i++) {
      final Offset next = Offset.lerp(from, to, i / safeSteps) ?? to;
      binding.handlePointerEvent(
        PointerMoveEvent(
          pointer: pointer,
          position: next,
          delta: next - previous,
          kind: PointerDeviceKind.touch,
          device: _device,
          buttons: kPrimaryButton,
        ),
      );
      previous = next;
    }

    binding.handlePointerEvent(
      PointerUpEvent(
        pointer: pointer,
        position: to,
        kind: PointerDeviceKind.touch,
        device: _device,
        buttons: kPrimaryButton,
      ),
    );
  }
}
