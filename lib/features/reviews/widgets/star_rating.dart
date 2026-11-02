import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A read-only 0–5 star row that fills partially for a fractional rating
/// (e.g. 4.8 shows nearly five stars). Part of the review UI, not a gesture
/// surface — see [StarRatingInput] for the tappable version.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.size = 20,
    this.color,
    this.tooltip,
  });

  /// Rating on the 0–5 scale (may be fractional).
  final double value;

  final double size;

  /// Star colour; defaults to the theme's primary (our teal).
  final Color? color;

  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color starColor = color ?? Theme.of(context).colorScheme.primary;
    final double clamped = value.clamp(0.0, 5.0);
    final Widget row = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 5; i++)
          SizedBox(
            width: size,
            height: size,
            child: _Star(
              fill: (clamped - i).clamp(0.0, 1.0),
              size: size,
              color: starColor,
            ),
          ),
      ],
    );
    final String? label = tooltip;
    return label == null ? row : Tooltip(message: label, child: row);
  }
}

/// A tappable 0–5 star row for the composer.
///
/// Tapping the star at index `n` selects `n` stars; tapping the first star again
/// when one star is selected clears the rating (a common affordance).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  /// Current rating as whole stars (`0` = none selected).
  final int value;

  /// Called with the new whole-star value (`0` clears).
  final ValueChanged<int> onChanged;

  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= 5; i++)
          InkResponse(
            onTap: () => onChanged(value == i ? 0 : i),
            radius: size * 0.7,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: size,
                height: size,
                child: _Star(
                  fill: i <= value ? 1 : 0,
                  size: size,
                  color: color,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A single star, filled from [fill] (`0..1`) using our own painted path.
class _Star extends StatelessWidget {
  const _Star({required this.fill, required this.size, required this.color});

  final double fill;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _StarPainter(
        fill: fill.clamp(0.0, 1.0),
        color: color,
        outline: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({
    required this.fill,
    required this.color,
    required this.outline,
  });

  final double fill;
  final Color color;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = _starPath(size);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true,
    );
    if (fill <= 0) {
      return;
    }
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * fill, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  Path _starPath(Size size) {
    const int points = 5;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double outer = size.shortestSide / 2 - 1;
    final double inner = outer * 0.44;
    final Path path = Path();
    for (int i = 0; i < points * 2; i++) {
      final double radius = i.isEven ? outer : inner;
      final double angle = -math.pi / 2 + i * math.pi / points;
      final Offset p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_StarPainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.color != color ||
      oldDelegate.outline != outline;
}
