import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format.dart';
import '../../../../domain/entities/transit.dart';
import 'transit_common.dart';
import 'transit_line_badge.dart';

/// The journey's leg-by-leg timeline: a rail of nodes and connecting lines on
/// the left (dotted for walking/transfers, a solid bar in the operator's colour
/// along each ride) with the stop names, times, platforms, wait times and ride
/// details on the right.
///
/// While guidance runs, a **live indicator** (a downward navigation arrow) sits
/// on the rail and moves down it with the traveller's actual progress through
/// the current leg.
class TransitTimeline extends StatefulWidget {
  const TransitTimeline({
    super.key,
    required this.itinerary,
    required this.originName,
    required this.destinationName,
    required this.imperial,
    this.liveLegIndex,
    this.liveFraction,
    this.onStopTap,
  });

  final TransitItinerary itinerary;
  final String originName;
  final String destinationName;
  final bool imperial;

  /// The leg the traveller is currently on, when guidance is running.
  final int? liveLegIndex;

  /// How far through the current leg, 0…1, positioning the live indicator.
  final double? liveFraction;

  /// Called when a stop row is tapped (opens the departures board).
  final void Function(TransitStop stop)? onStopTap;

  @override
  State<TransitTimeline> createState() => _TransitTimelineState();
}

class _TransitTimelineState extends State<TransitTimeline> {
  final GlobalKey _overlayKey = GlobalKey();
  GlobalKey? _startKey;
  GlobalKey? _endKey;
  int? _keyedLeg;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  /// Keeps the rail anchors stable for a given live leg (recreating them every
  /// build would reset the stateful ride details).
  void _syncKeys() {
    if (_keyedLeg == widget.liveLegIndex) {
      return;
    }
    _keyedLeg = widget.liveLegIndex;
    _startKey = widget.liveLegIndex == null ? null : GlobalKey();
    _endKey = widget.liveLegIndex == null ? null : GlobalKey();
  }

  @override
  Widget build(BuildContext context) {
    _syncKeys();
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TransitItinerary itinerary = widget.itinerary;
    final bool imperial = widget.imperial;
    final int? liveLegIndex = widget.liveLegIndex;
    final List<TransitLeg> legs = itinerary.legs;
    final _TimelineConnector dotted = _TimelineConnector(
      color: scheme.outlineVariant,
      dashed: true,
    );
    final List<Widget> rows = <Widget>[];

    // Origin.
    final TransitStop? originStop = itinerary.originStop;
    rows.add(
      _TimelineRow(
        entry: _TimelineEntry(
          node: _OriginNode(color: scheme.primary),
          below: dotted,
          child: _StopPointRow(
            name: widget.originName,
            trailing: transitClock(context, itinerary.startTime.toLocal()),
            onTap: originStop == null ? null : _onTapFor(originStop),
          ),
        ),
      ),
    );

    for (int i = 0; i < legs.length; i++) {
      final TransitLeg leg = legs[i];
      final bool live = liveLegIndex == i;
      final Duration wait = itinerary.waitBefore(i);
      if (wait.inMinutes >= 1) {
        rows.add(
          _TimelineRow(
            entry: _TimelineEntry(
              node: Icon(Icons.schedule, size: 18, color: scheme.outline),
              above: dotted,
              below: dotted,
              child: Text(
                'Wait ${formatDuration(wait)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ),
          ),
        );
      }
      if (leg.isTransit) {
        final _TimelineConnector ride = _TimelineConnector(
          color: Color(leg.displayColor),
          width: 4,
        );
        // Board — the rail anchor where the live indicator starts on this ride.
        rows.add(
          _TimelineRow(
            key: live ? _startKey : null,
            entry: _TimelineEntry(
              node: _ModeNode(leg: leg),
              above: dotted,
              below: ride,
              child: _StopPointRow(
                name: leg.from.name,
                trailing: transitClock(context, leg.startTime.toLocal()),
                track: leg.from.hasTrack ? leg.from.displayTrack : null,
                onTap: _onTapFor(leg.from),
              ),
            ),
          ),
        );
        // The ride itself (badge, headsign, status, stops).
        rows.add(
          _TimelineRow(
            entry: _TimelineEntry(
              above: ride,
              below: ride,
              child: _RideDetails(leg: leg),
            ),
          ),
        );
        // Alight — the rail anchor where the indicator ends on this ride.
        rows.add(
          _TimelineRow(
            key: live ? _endKey : null,
            entry: _TimelineEntry(
              node: _AlightNode(color: Color(leg.displayColor)),
              above: ride,
              below: dotted,
              child: _StopPointRow(
                name: leg.to.name,
                trailing: transitClock(context, leg.endTime.toLocal()),
                track: leg.to.hasTrack ? leg.to.displayTrack : null,
                onTap: _onTapFor(leg.to),
              ),
            ),
          ),
        );
      } else {
        rows.add(
          _TimelineRow(
            key: live ? _startKey : null,
            entry: _TimelineEntry(
              node: Icon(
                transitModeIcon(leg.mode),
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              above: dotted,
              below: dotted,
              child: _WalkLegRow(
                leg: leg,
                imperial: imperial,
                onTap: _onTapFor(leg.to),
              ),
            ),
          ),
        );
      }
    }

    // Destination.
    rows.add(
      _TimelineRow(
        entry: _TimelineEntry(
          node: Icon(Icons.place, size: 22, color: scheme.error),
          above: dotted,
          child: _StopPointRow(
            name: widget.destinationName,
            trailing: transitClock(context, itinerary.endTime.toLocal()),
          ),
        ),
      ),
    );

    final Widget column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
    final GlobalKey? startKey = _startKey;
    if (liveLegIndex == null || startKey == null) {
      return column;
    }
    return Stack(
      key: _overlayKey,
      clipBehavior: Clip.none,
      children: <Widget>[
        column,
        _LiveRailIndicator(
          overlayKey: _overlayKey,
          startKey: startKey,
          endKey: _endKey,
          fraction: (widget.liveFraction ?? 0).clamp(0, 1),
        ),
      ],
    );
  }

  VoidCallback? _onTapFor(TransitStop stop) {
    final void Function(TransitStop stop)? handler = widget.onStopTap;
    final String? id = stop.id?.trim();
    if (handler == null || id == null || id.isEmpty) {
      return null;
    }
    return () => handler(stop);
  }
}

/// Positions the live navigation arrow on the rail, measured from the current
/// leg's start and end rows and moved down by [fraction] (0 → start, 1 → end).
class _LiveRailIndicator extends StatefulWidget {
  const _LiveRailIndicator({
    required this.overlayKey,
    required this.startKey,
    required this.fraction,
    this.endKey,
  });

  final GlobalKey overlayKey;
  final GlobalKey startKey;
  final GlobalKey? endKey;
  final double fraction;

  @override
  State<_LiveRailIndicator> createState() => _LiveRailIndicatorState();
}

class _LiveRailIndicatorState extends State<_LiveRailIndicator> {
  double? _top;

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _LiveRailIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _measure();
      }
    });
  }

  void _measure() {
    final RenderObject? overlay = widget.overlayKey.currentContext
        ?.findRenderObject();
    final RenderObject? start = widget.startKey.currentContext
        ?.findRenderObject();
    if (overlay is! RenderBox || start is! RenderBox) {
      return;
    }
    final double startY = start
        .localToGlobal(Offset.zero, ancestor: overlay)
        .dy;
    final RenderObject? end = widget.endKey?.currentContext?.findRenderObject();
    final double endY = end is RenderBox
        ? end.localToGlobal(Offset.zero, ancestor: overlay).dy
        : startY + start.size.height;
    final double top = startY + (endY - startY) * widget.fraction;
    if (!mounted) {
      return;
    }
    if (_top == null || (_top! - top).abs() > 0.5) {
      setState(() => _top = top);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? top = _top;
    if (top == null) {
      return const SizedBox.shrink();
    }
    return Positioned(top: top, left: 5, child: const _LiveNode());
  }
}

/// A node and its content on one timeline row.
@immutable
class _TimelineEntry {
  const _TimelineEntry({
    required this.child,
    this.node,
    this.above,
    this.below,
  });

  final Widget child;

  /// The marker drawn on the rail; a `null` node draws a bare connecting line.
  final Widget? node;
  final _TimelineConnector? above;
  final _TimelineConnector? below;
}

/// The style of a rail connector segment.
@immutable
class _TimelineConnector {
  const _TimelineConnector({
    required this.color,
    this.width = 2,
    this.dashed = false,
  });

  final Color color;
  final double width;
  final bool dashed;

  @override
  bool operator ==(Object other) =>
      other is _TimelineConnector &&
      other.color == color &&
      other.width == width &&
      other.dashed == dashed;

  @override
  int get hashCode => Object.hash(color, width, dashed);
}

/// One timeline row: the rail on the left (stretched to the content height) and
/// the content on the right.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({super.key, required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: _Rail(
              node: entry.node,
              above: entry.above,
              below: entry.below,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: entry.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rail: a node pinned to the top of the row with the connector segments
/// painted above and below it.
class _Rail extends StatelessWidget {
  const _Rail({this.node, this.above, this.below});

  final Widget? node;
  final _TimelineConnector? above;
  final _TimelineConnector? below;

  static const double _nodeSize = 24;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(
        above: above,
        below: below,
        hasNode: node != null,
        nodeCenter: _nodeSize / 2,
        nodeRadius: _nodeSize / 2,
      ),
      child: node == null
          ? const SizedBox.expand()
          : Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: _nodeSize,
                height: _nodeSize,
                child: Center(child: node),
              ),
            ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.above,
    required this.below,
    required this.hasNode,
    required this.nodeCenter,
    required this.nodeRadius,
  });

  final _TimelineConnector? above;
  final _TimelineConnector? below;
  final bool hasNode;
  final double nodeCenter;
  final double nodeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final double x = size.width / 2;
    const double gap = 3;
    final double nodeTop = hasNode ? nodeCenter - nodeRadius - gap : 0;
    final double nodeBottom = hasNode ? nodeCenter + nodeRadius + gap : 0;
    if (above != null) {
      _stroke(canvas, above!, Offset(x, 0), Offset(x, nodeTop));
    }
    if (below != null) {
      _stroke(canvas, below!, Offset(x, nodeBottom), Offset(x, size.height));
    }
  }

  void _stroke(
    Canvas canvas,
    _TimelineConnector connector,
    Offset a,
    Offset b,
  ) {
    if (b.dy <= a.dy) {
      return;
    }
    final Paint paint = Paint()
      ..color = connector.color
      ..strokeWidth = connector.width
      ..strokeCap = StrokeCap.round;
    if (!connector.dashed) {
      canvas.drawLine(a, b, paint);
      return;
    }
    const double dash = 2.5;
    const double gap = 3.5;
    double y = a.dy;
    while (y < b.dy) {
      final double end = (y + dash).clamp(a.dy, b.dy);
      canvas.drawLine(Offset(a.dx, y), Offset(b.dx, end), paint);
      y = end + gap;
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      oldDelegate.above != above ||
      oldDelegate.below != below ||
      oldDelegate.hasNode != hasNode ||
      oldDelegate.nodeCenter != nodeCenter ||
      oldDelegate.nodeRadius != nodeRadius;
}

/// "Your location": a filled dot with a surface ring.
class _OriginNode extends StatelessWidget {
  const _OriginNode({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 3,
        ),
      ),
    );
  }
}

/// A boarding stop: the mode glyph in the operator's colour.
class _ModeNode extends StatelessWidget {
  const _ModeNode({required this.leg});

  final TransitLeg leg;

  @override
  Widget build(BuildContext context) {
    final Color background = Color(leg.displayColor);
    final Color foreground = leg.routeTextColor != null
        ? Color(leg.routeTextColor!)
        : (background.computeLuminance() > 0.5
              ? const Color(0xFF10161A)
              : const Color(0xFFFFFFFF));
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Icon(transitModeIcon(leg.mode), size: 14, color: foreground),
    );
  }
}

/// An alighting stop: a hollow circle in the operator's colour.
class _AlightNode extends StatelessWidget {
  const _AlightNode({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: color, width: 3),
      ),
    );
  }
}

/// The live position indicator: a filled brand-coloured disc with a downward
/// navigation arrow, marking how far the traveller is on the journey rail.
class _LiveNode extends StatelessWidget {
  const _LiveNode();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        border: Border.all(color: scheme.surface, width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      // The arrow points down the rail (the direction of travel).
      child: Transform.rotate(
        angle: math.pi,
        child: Icon(
          Icons.navigation,
          size: 12,
          color: scheme.onPrimary,
          semanticLabel: 'Current position',
        ),
      ),
    );
  }
}

/// A stop name with its time and (at transfers) its platform/track.
class _StopPointRow extends StatelessWidget {
  const _StopPointRow({
    required this.name,
    required this.trailing,
    this.track,
    this.onTap,
  });

  final String name;
  final String trailing;
  final String? track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Text(name, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (track != null) ...<Widget>[
          _TrackChip(track: track!),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
    final VoidCallback? tap = onTap;
    if (tap == null) {
      return row;
    }
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

/// A walking/biking leg: "Walk 4 min (260 m)" and its arrival time.
class _WalkLegRow extends StatelessWidget {
  const _WalkLegRow({required this.leg, required this.imperial, this.onTap});

  final TransitLeg leg;
  final bool imperial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget row = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            '${leg.mode.label} ${formatDuration(leg.duration)} '
            '(${formatDistance(leg.distanceMeters, imperial: imperial)})',
          ),
        ),
        Text(
          transitClock(context, leg.endTime.toLocal()),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
    final VoidCallback? tap = onTap;
    if (tap == null) {
      return row;
    }
    return InkWell(
      onTap: tap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

/// The ride's line, status and — expandable — the stops it calls at.
class _RideDetails extends StatefulWidget {
  const _RideDetails({required this.leg});

  final TransitLeg leg;

  @override
  State<_RideDetails> createState() => _RideDetailsState();
}

class _RideDetailsState extends State<_RideDetails> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final TransitLeg leg = widget.leg;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<TransitStop> stops = leg.intermediateStops;
    final Duration? delay = leg.departureDelay;
    final bool delayed = delay != null && delay.inMinutes.abs() >= 1;
    final String? status = delayed
        ? transitDelayLabel(delay)
        : (leg.realTime ? 'On time' : null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            TransitLineBadge(leg: leg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                leg.headsign?.isNotEmpty == true
                    ? 'to ${leg.headsign}'
                    : leg.routeLongName ?? leg.mode.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatDuration(leg.duration),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        if (status != null)
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: delayed ? scheme.error : scheme.primary),
          ),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                transitClock(
                  context,
                  (leg.scheduledStartTime ?? leg.startTime).toLocal(),
                ),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ),
            if (stops.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  '${stops.length} ${stops.length == 1 ? 'stop' : 'stops'}',
                ),
              ),
          ],
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final TransitStop stop in stops)
                  _IntermediateStopRow(stop: stop, color: leg.displayColor),
              ],
            ),
          ),
      ],
    );
  }
}

/// A single stop called at, with the white-centred circle we draw on the map.
class _IntermediateStopRow extends StatelessWidget {
  const _IntermediateStopRow({required this.stop, required this.color});

  final TransitStop stop;
  final int color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          _StopDot(color: color, size: 12),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              stop.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (stop.hasTrack) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            _TrackChip(track: stop.displayTrack!),
          ],
        ],
      ),
    );
  }
}

/// A circle with a white centre and a coloured ring — the same mark the map
/// uses for a transit stop.
class _StopDot extends StatelessWidget {
  const _StopDot({required this.color, this.size = 16});

  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: Color(color), width: size < 14 ? 3 : 4),
      ),
    );
  }
}

/// A platform/track chip, e.g. "Platform 7" — shown at boarding stops and, in
/// particular, where a journey changes vehicles.
class _TrackChip extends StatelessWidget {
  const _TrackChip({required this.track});

  final String track;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(
        'Platform $track',
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
