import 'package:flutter/widgets.dart';

/// Tactile press feedback for the play kit.
///
/// Material answers a tap with an ink ripple; Play answers with a small
/// spring-like squash. This is the one shared implementation so every
/// interactive atom feels identical, and it carries the button semantics a
/// screen reader needs without pulling in Material.
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

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  void _setDown(bool value) {
    if (_down != value && mounted) {
      setState(() => _down = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: MouseRegion(
        cursor: _interactive
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _interactive ? widget.onTap : null,
          onLongPress: _interactive ? widget.onLongPress : null,
          onTapDown: _interactive ? (TapDownDetails _) => _setDown(true) : null,
          onTapUp: _interactive ? (TapUpDetails _) => _setDown(false) : null,
          onTapCancel: _interactive ? () => _setDown(false) : null,
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
