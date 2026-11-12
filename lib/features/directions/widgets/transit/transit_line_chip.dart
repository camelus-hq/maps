import 'package:flutter/material.dart';

/// A coloured line chip ("S41", "U8", "Bus 100"): the operator's own colour
/// with the line's label, used for the lines serving a stop and for departure
/// rows. Falls back to our own mode palette when the provider reported no
/// colour, and picks a legible text colour from the background.
class TransitLineChip extends StatelessWidget {
  const TransitLineChip({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.minWidth = 34,
  });

  /// The line label ("U7", "S41", "Bus 100").
  final String label;

  /// The chip's background colour as ARGB.
  final int color;

  /// The provider's text colour as ARGB, when given.
  final int? textColor;

  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final Color background = Color(color);
    final Color foreground = Color(
      textColor ??
          (background.computeLuminance() > 0.5 ? 0xFF10161A : 0xFFFFFFFF),
    );
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
