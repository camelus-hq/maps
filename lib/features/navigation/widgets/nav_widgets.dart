import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/route.dart';
import '../../../domain/entities/travel_mode.dart';
import '../../../state/navigation.dart';
import '../../design/play.dart';
import '../../directions/widgets/maneuver_glyph.dart';
import '../nav_style.dart';
import 'lane_glyph.dart';

/// The dark instruction banner at the top of guidance.
///
/// Shows the next-maneuver glyph, the distance to it and the street, and — for
/// modes that support it — a lane-guidance strip. The banner emphasises itself
/// as the turn approaches (accent border, brighter fill, a progress bar).
class NavBanner extends StatelessWidget {
  const NavBanner({
    super.key,
    required this.nav,
    required this.style,
    required this.imperial,
    this.onTap,
  });

  final NavState nav;
  final NavStyle style;
  final bool imperial;
  final VoidCallback? onTap;

  /// How far before a "soon" turn the progress bar saturates (a multiple of the
  /// soon threshold, so the bar fills gradually).
  static const double _progressSpanFactor = 3;

  @override
  Widget build(BuildContext context) {
    final Maneuver? maneuver = nav.nextManeuver;
    final bool arrived = nav.status == NavStatus.arrived;
    final bool rerouting = nav.status == NavStatus.rerouting;
    final ManeuverType type = arrived
        ? ManeuverType.arrive
        : (maneuver?.type ?? ManeuverType.straight);
    final double distance = nav.distanceToNextManeuver;
    final NavUrgency urgency = arrived || rerouting
        ? NavUrgency.none
        : style.urgency(distance);
    final Color background = urgency == NavUrgency.now
        ? style.bannerNow
        : style.banner;
    final Color border = switch (urgency) {
      NavUrgency.now => style.bannerAccent,
      NavUrgency.soon => const Color(0xFFF2B23E),
      NavUrgency.none => const Color(0x00000000),
    };
    final String primaryText = arrived
        ? 'You have arrived'
        : rerouting
        ? 'Rerouting…'
        : formatDistance(distance, imperial: imperial);
    final String? street = arrived || rerouting ? null : maneuver?.streetName;
    final String? instruction = arrived || rerouting
        ? null
        : _instructionOf(maneuver);

    return PlayPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(PlayRadii.md),
          border: Border.all(
            color: border,
            width: urgency == NavUrgency.none ? 0 : 2,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(PlaySpace.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  ManeuverGlyph(
                    type: type,
                    size: 54,
                    color: style.bannerAccent,
                  ),
                  const SizedBox(width: PlaySpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          primaryText,
                          style: TextStyle(
                            color: style.bannerAccent,
                            fontSize: urgency == NavUrgency.now ? 34 : 30,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        if (street != null) ...<Widget>[
                          Text(
                            'toward',
                            style: TextStyle(
                              color: style.bannerAccent.withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            street,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.bannerAccent,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ] else if (instruction != null)
                          Text(
                            instruction,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: style.bannerAccent.withValues(alpha: 0.92),
                              fontSize: 21,
                              height: 1.15,
                            ),
                          ),
                        if (urgency != NavUrgency.none) ...<Widget>[
                          const SizedBox(height: PlaySpace.sm),
                          _ApproachBar(
                            progress: _approachProgress(distance),
                            color: style.bannerAccent,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (style.showLanes &&
                maneuver != null &&
                maneuver.lanes.isNotEmpty)
              NavLaneStrip(style: style, lanes: maneuver.lanes),
          ],
        ),
      ),
    );
  }

  /// 0 → far (an empty bar), 1 → at the turn (a full bar).
  double _approachProgress(double distance) {
    final double span = style.soonMeters * _progressSpanFactor;
    if (span <= 0) {
      return 0;
    }
    return (1 - distance / span).clamp(0.0, 1.0);
  }

  static String? _instructionOf(Maneuver? maneuver) {
    final String? instruction = maneuver?.instruction;
    return (instruction == null || instruction.isEmpty) ? null : instruction;
  }
}

class _ApproachBar extends StatelessWidget {
  const _ApproachBar({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 5,
        child: Stack(
          children: <Widget>[
            Container(color: color.withValues(alpha: 0.22)),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              widthFactor: progress,
              alignment: Alignment.centerLeft,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lane-guidance strip under the instruction (drive only).
class NavLaneStrip extends StatelessWidget {
  const NavLaneStrip({super.key, required this.style, required this.lanes});

  final NavStyle style;
  final List<LaneGuidance> lanes;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: style.laneStrip,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: PlaySpace.lg,
        vertical: PlaySpace.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < lanes.length; i++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: LaneGlyph(
                indication: lanes[i].primary,
                size: 30,
                // The lane to take (Valhalla `active`) is drawn bright; the
                // others are dimmed, with a slightly stronger tone for lanes
                // that still lead through the maneuver (`valid`).
                color: style.bannerAccent.withValues(
                  alpha: lanes[i].active ? 1 : (lanes[i].valid ? 0.55 : 0.35),
                ),
              ),
            ),
            // A short divider between lanes, like the markings on the road.
            if (i < lanes.length - 1)
              Container(
                width: 2,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                color: style.bannerAccent.withValues(alpha: 0.32),
              ),
          ],
        ],
      ),
    );
  }
}

/// Speed-limit sign + current speed chip (drive/cycle).
class NavSpeedChip extends StatelessWidget {
  const NavSpeedChip({
    super.key,
    required this.limitKmh,
    required this.currentKmh,
    required this.imperial,
  });

  final int? limitKmh;
  final double? currentKmh;
  final bool imperial;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    final int? limit = limitKmh;
    final double? speed = currentKmh;
    return PlaySurface(
      backgroundColor: colors.surface,
      radius: PlayRadii.md,
      shadow: PlayShadow.soft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (limit != null) ...<Widget>[
              _SpeedLimitSign(value: limit),
              const SizedBox(width: PlaySpace.sm),
            ],
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  speed == null
                      ? '--'
                      : (imperial
                            ? '${(speed * 0.621371).round()}'
                            : '${speed.round()}'),
                  style: PlayType.title.copyWith(color: colors.ink),
                ),
                Text(
                  imperial ? 'mph' : 'km/h',
                  style: PlayType.caption.copyWith(color: colors.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.statusClosed, width: 4),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: const TextStyle(
          color: Color(0xFF000000),
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// The floating "Re-center" pill shown during guidance once the user has taken
/// the camera away from the position (a manual pan/pinch/zoom). Tapping it flies
/// back to the current position and resumes tracking (`nav.resume`).
class NavRecenterButton extends StatelessWidget {
  const NavRecenterButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return PlaySurface(
      backgroundColor: colors.surface,
      radius: PlayRadii.pill,
      shadow: PlayShadow.soft,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PlaySpace.lg,
          vertical: PlaySpace.sm + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(PlayIcons.navigation, size: 20, color: colors.primary),
            const SizedBox(width: PlaySpace.sm),
            Text(
              'Re-center',
              style: PlayType.bodyStrong.copyWith(color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// The right-hand floating controls during guidance.
class NavSideControls extends StatelessWidget {
  const NavSideControls({
    super.key,
    required this.tracking,
    required this.onToggleOverview,
  });

  final bool tracking;
  final VoidCallback onToggleOverview;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SideButton(
          icon: tracking ? PlayIcons.mapStandard : PlayIcons.navigation,
          semanticLabel: tracking ? 'Route overview' : 'Re-center',
          onPressed: onToggleOverview,
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PlayIconButton(
      icon: icon,
      size: 48,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
    );
  }
}

@PlayPreview(name: 'NavBanner', size: Size(420, 260))
Widget navBannerPreview() => PlayPreviewFrame(
  child: NavBanner(
    nav: const NavState(
      status: NavStatus.navigating,
      mode: TravelMode.drive,
      totalMeters: 1700,
      traveledMeters: 1480,
      distanceToNextManeuver: 220,
      nextManeuver: Maneuver(
        instruction: 'Turn left onto Messedamm',
        type: ManeuverType.turnLeft,
        streetName: 'Messedamm',
        lanes: <LaneGuidance>[
          LaneGuidance(indications: <LaneIndication>[LaneIndication.left]),
          LaneGuidance(
            active: true,
            valid: true,
            indications: <LaneIndication>[LaneIndication.left],
          ),
          LaneGuidance(indications: <LaneIndication>[LaneIndication.straight]),
          LaneGuidance(indications: <LaneIndication>[LaneIndication.right]),
        ],
      ),
    ),
    style: NavStyle.forMode(TravelMode.drive),
    imperial: false,
  ),
);

@PlayPreview(name: 'NavSpeedChip', size: Size(300, 160))
Widget navSpeedChipPreview() => const PlayPreviewFrame(
  child: NavSpeedChip(limitKmh: 50, currentKmh: 42, imperial: false),
);

@PlayPreview(name: 'NavRecenterButton', size: Size(320, 140))
Widget navRecenterButtonPreview() =>
    PlayPreviewFrame(child: NavRecenterButton(onPressed: () {}));
