import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/play/play_colors.dart';
import '../../../core/theme/play/play_tokens.dart';
import 'play_surface.dart';

/// A long-press tooltip in the play style — our replacement for Material's
/// `Tooltip`.
///
/// Long-pressing [child] floats a small dark bubble with [message] just below
/// it; it hides itself after [duration], on a second long press, or when the
/// widget goes away. It is pointer-transparent, so taps still reach the widget
/// underneath. Flutter's `Tooltip` lives in the Material library, which the
/// play kit deliberately does not use.
class PlayTooltip extends StatefulWidget {
  const PlayTooltip({
    super.key,
    required this.message,
    required this.child,
    this.duration = const Duration(seconds: 3),
    this.maxWidth = 260,
  });

  /// The text shown in the bubble.
  final String message;

  /// The widget that opens the tooltip on a long press.
  final Widget child;

  /// How long the bubble stays up once shown.
  final Duration duration;

  /// The widest the bubble may grow before the text wraps.
  final double maxWidth;

  @override
  State<PlayTooltip> createState() => _PlayTooltipState();
}

class _PlayTooltipState extends State<PlayTooltip> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    // The overlay entry is a descendant of this element's overlay ancestor, so
    // tearing the tree down disposes this element first and the remove is safe.
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _toggle() {
    if (_entry != null) {
      _hide();
      return;
    }
    _show();
  }

  void _show() {
    final PlayColors colors = PlayColors.of(context);
    _entry = OverlayEntry(builder: (BuildContext context) => _bubble(colors));
    Overlay.of(context).insert(_entry!);
    _timer = Timer(widget.duration, _hide);
  }

  void _hide() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  Widget _bubble(PlayColors colors) {
    return Positioned.fill(
      // The bubble must never steal the tap that belongs to the widget below.
      child: IgnorePointer(
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomCenter,
          followerAnchor: Alignment.topCenter,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxWidth),
              child: PlaySurface(
                backgroundColor: colors.strong,
                radius: PlayRadii.md,
                shadow: PlayShadow.soft,
                padding: const EdgeInsets.symmetric(
                  horizontal: PlaySpace.md,
                  vertical: PlaySpace.sm,
                ),
                child: Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: PlayType.caption.copyWith(color: colors.onStrong),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only a long press is claimed, so a tap falls through to an enclosing
    // pressable (the rating row opens the Reviews tab).
    return CompositedTransformTarget(
      link: _link,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          LongPressGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                // A widened slop, so the long press survives the small finger
                // drift a real touch has inside a scrollable sheet.
                () => LongPressGestureRecognizer(postAcceptSlopTolerance: 32),
                (LongPressGestureRecognizer instance) {
                  instance.onLongPress = _toggle;
                },
              ),
        },
        child: widget.child,
      ),
    );
  }
}
