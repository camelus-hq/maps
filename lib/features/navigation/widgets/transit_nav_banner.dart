import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/transit.dart';
import '../../../state/navigation.dart';
import '../../directions/widgets/maneuver_glyph.dart';
import '../../directions/widgets/transit/transit_common.dart';
import '../nav_style.dart';

/// The public-transport instruction card at the top of guidance.
///
/// It keeps the shared guidance card shape (a maneuver glyph, the distance to
/// the next action and the action itself) and extends it with a status strip —
/// the line badge, its punctuality ("Scheduled · 10:50 AM", "On time",
/// "3 min late") and, while riding, how many stops are left — so the traveller
/// has the immediate instruction and the line's state in one glance.
class TransitNavBanner extends StatelessWidget {
  const TransitNavBanner({
    super.key,
    required this.nav,
    required this.itinerary,
    required this.progress,
    required this.style,
    required this.imperial,
    this.onTap,
  });

  final NavState nav;
  final TransitItinerary itinerary;
  final TransitProgress progress;
  final NavStyle style;
  final bool imperial;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool arrived =
        nav.status == NavStatus.arrived ||
        progress.phase == TransitPhase.arrived;
    final ManeuverType glyph = arrived
        ? ManeuverType.arrive
        : ManeuverType.straight;
    final double distance = progress.remainingInLeg;
    final TransitLeg? ride = arrived ? null : progress.ride;
    // On foot the card leads with the distance to the next action; on board it
    // leads with the ride's remaining time (the reference's behaviour) — the
    // line status strip carries the stops left and the arrival clock.
    final String primaryText = arrived
        ? 'Arrived'
        : (progress.onBoard && ride != null)
        ? formatDuration(rideRemaining(ride, progress))
        : formatDistance(distance, imperial: imperial);
    final String instruction = _instruction();
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.banner,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    ManeuverGlyph(
                      type: glyph,
                      size: 54,
                      color: style.bannerAccent,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            primaryText,
                            style: TextStyle(
                              color: style.bannerAccent,
                              fontSize: 30,
                              fontWeight: FontWeight.w600,
                              height: 1.05,
                            ),
                          ),
                          Text(
                            instruction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.bannerAccent.withValues(alpha: 0.92),
                              fontSize: 19,
                              height: 1.18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (ride != null)
                _TransitStatusStrip(
                  leg: ride,
                  progress: progress,
                  style: style,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _instruction() {
    if (nav.status == NavStatus.arrived ||
        progress.phase == TransitPhase.arrived) {
      return 'at ${itinerary.destinationStop?.name ?? 'your destination'}';
    }
    final TransitLeg? ride = progress.ride;
    if (ride == null) {
      // The final walk to the destination.
      return 'Walk to ${itinerary.destinationStop?.name ?? 'your destination'}';
    }
    if (progress.onBoard) {
      final String to = ride.to.name;
      return progress.stopsRemaining <= 2 ? 'Get off at $to' : 'Ride to $to';
    }
    return 'Board ${ride.lineLabel} to ${_headsign(ride, ride.to.name)}';
  }

  static String _headsign(TransitLeg leg, String fallback) {
    final String? headsign = leg.headsign?.trim();
    return (headsign == null || headsign.isEmpty) ? fallback : headsign;
  }
}

/// The badge + punctuality strip along the bottom of the transit card.
class _TransitStatusStrip extends StatelessWidget {
  const _TransitStatusStrip({
    required this.leg,
    required this.progress,
    required this.style,
  });

  final TransitLeg leg;
  final TransitProgress progress;
  final NavStyle style;

  @override
  Widget build(BuildContext context) {
    final Color foreground = style.bannerAccent;
    final int background = leg.displayColor;
    final int textColor =
        leg.routeTextColor ??
        (Color(background).computeLuminance() > 0.5 ? 0xFF10161A : 0xFFFFFFFF);
    final String? track = progress.onBoard || !leg.from.hasTrack
        ? null
        : leg.from.displayTrack;
    final String status = progress.onBoard
        ? _rideSummary(context)
        : _boardingStatus(context);
    return Container(
      width: double.infinity,
      color: style.laneStrip,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Color(background),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              leg.lineLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Color(textColor),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (track != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TransitPlatformChip(track: track),
          ],
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// While riding: how many stops are left and the arrival clock (the ride's
  /// remaining time is the card's headline).
  String _rideSummary(BuildContext context) {
    final int stops = progress.stopsRemaining;
    final String stopsLabel = stops == 1 ? '1 stop' : '$stops stops';
    final String clock = transitClock(context, leg.endTime.toLocal());
    return '$stopsLabel · arrives $clock';
  }

  /// Before boarding: the punctuality (only when there is live information),
  /// then the relative ("in 7 min") and absolute departure clock.
  String _boardingStatus(BuildContext context) {
    final String clock = transitClock(context, leg.startTime.toLocal());
    final String? relative = relativeTimeLabel(leg.startTime.toLocal());
    // "On time"/"3 min late" only makes sense with a live feed; a scheduled
    // train just shows its time.
    final String? status = (leg.realTime || leg.cancelled)
        ? transitRideStatus(leg)
        : null;
    return <String>[?status, ?relative, clock].join(' · ');
  }
}

/// How long is left on a ride (proportional to how far through its geometry the
/// traveller is).
Duration rideRemaining(TransitLeg leg, TransitProgress progress) => Duration(
  seconds: (leg.duration.inSeconds * (1 - progress.fractionInLeg)).round(),
);
