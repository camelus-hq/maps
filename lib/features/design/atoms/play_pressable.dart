import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Tactile press feedback for the play kit.
///
/// Material answers a tap with an ink ripple; Play answers with a small
/// spring-like squash. This is the one shared implementation so every
/// interactive atom feels identical, and it carries the button semantics a
/// screen reader needs without pulling in Material.
///
/// The recognizers are wired by hand (rather than through `GestureDetector`) for
/// two reasons:
///  * the long-press slop is widened, so a long press inside a scrollable/modal
///    sheet survives the small finger drift a real touch always has (otherwise
///    the outer drag wins and the long press never fires, and the release lands
///    as a bogus tap — the "long press opens the chip" bug); and
///  * a tap that still slips through after a recognised long press is swallowed.
class PlayPressable extends StatefulWidget {
  const PlayPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// How far to shrink while held.
  final double scale;

  @override
  State<PlayPressable> createState() => _PlayPressableState();
}

class _PlayPressableState extends State<PlayPressable> {
  bool _down = false;
  bool _longPressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setDown(bool value) {
    if (_down != value && mounted) {
      setState(() => _down = value);
    }
  }

  void _handleTap() {
    // A long press already answered this gesture; drop the stray tap.
    if (_longPressed) {
      _longPressed = false;
      return;
    }
    widget.onTap?.call();
  }

  void _handleLongPress() {
    _longPressed = true;
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory>
    gestures = <Type, GestureRecognizerFactory>{
      TapGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
            TapGestureRecognizer.new,
            (TapGestureRecognizer instance) {
              instance
                ..onTap = _interactive ? _handleTap : null
                ..onTapDown = _interactive
                    ? (TapDownDetails _) {
                        _longPressed = false;
                        _setDown(true);
                      }
                    : null
                ..onTapUp = _interactive
                    ? (TapUpDetails _) => _setDown(false)
                    : null
                ..onTapCancel = _interactive ? () => _setDown(false) : null;
            },
          ),
      if (widget.onLongPress != null)
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(postAcceptSlopTolerance: 32),
              (LongPressGestureRecognizer instance) {
                instance.onLongPress = _interactive ? _handleLongPress : null;
              },
            ),
    };

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: gestures,
          child: AnimatedScale(
            scale: _down ? widget.scale : 1,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
