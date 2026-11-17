import 'package:flutter/widgets.dart';

import '../../core/theme/play/play_colors.dart';
import '../../core/theme/play/play_tokens.dart';

/// A shimmering placeholder surface for content that is still loading.
///
/// Wrap any tree of [ShimmerBox]es in a [Shimmer]: a single moving highlight is
/// masked across the whole subtree, so a skeleton built from several boxes
/// shimmers as one piece and animates from one ticker instead of one per box.
///
/// The colours come from the active play palette (a recessed block with the ink
/// blended through it), so the shimmer reads correctly in both light and dark.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 1400),
  });

  /// The skeleton content — usually a tree of [ShimmerBox]es.
  final Widget child;

  /// How long one sweep of the highlight takes.
  final Duration period;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final Color base = colors.surfaceSunken;
    final Color highlight = Color.alphaBlend(
      colors.ink.withValues(alpha: 0.08),
      base,
    );
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (Rect bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[base, highlight, base],
          stops: const <double>[0.25, 0.5, 0.75],
          transform: _SlidingGradient(_controller.value * 2 - 1),
        ).createShader(bounds),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Shifts a gradient horizontally so its highlight sweeps from just off the
/// left edge to just off the right edge as the shimmer advances.
class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.slide);

  /// -1 (fully left) … 0 (centred) … 1 (fully right).
  final double slide;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * slide, 0, 0);
}

/// One block of a loading skeleton, animated by an enclosing [Shimmer].
///
/// Use [width] to shape a text line, or [circle] for an icon placeholder.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = PlayRadii.xs,
    this.circle = false,
  });

  /// The block width, or `null` to fill the available width.
  final double? width;
  final double height;

  /// The corner radius of a rectangular block.
  final double radius;

  /// Renders a circle of diameter [height] (an icon placeholder).
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Container(
      width: circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}
