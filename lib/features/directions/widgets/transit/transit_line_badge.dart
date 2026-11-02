import 'package:flutter/material.dart';

import '../../../../domain/entities/transit.dart';

/// A coloured line badge ("U7", "Bus 100", …) using the operator's own colour
/// when the provider reported one, and our own mode palette otherwise.
class TransitLineBadge extends StatelessWidget {
  const TransitLineBadge({super.key, required this.leg, this.size = 22});

  final TransitLeg leg;
  final double size;

  @override
  Widget build(BuildContext context) {
    final int background = leg.displayColor;
    final int foreground =
        leg.routeTextColor ??
        (Color(background).computeLuminance() > 0.5 ? 0xFF10161A : 0xFFFFFFFF);
    return Container(
      constraints: BoxConstraints(minWidth: size),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color(background),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        leg.lineLabel,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: Color(foreground), fontWeight: FontWeight.w600),
      ),
    );
  }
}
