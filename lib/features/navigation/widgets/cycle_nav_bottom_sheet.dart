import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/format.dart';
import '../../../domain/entities/elevation.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import 'cycle_gradient_profile.dart';
import 'nav_sheet.dart';

/// The cycling navigation sheet.
///
/// It opens one notch higher than the car sheet and leads with a horizontally
/// swipeable board of ride stats — distance/speed/to-end/average, then
/// timing/distance, and (when the router supplies elevation) an elevation
/// gradient profile. As a notable climb comes up the board slides to the
/// gradient page on its own.
class CycleNavBottomSheet extends ConsumerStatefulWidget {
  const CycleNavBottomSheet({
    super.key,
    required this.nav,
    required this.tracking,
    required this.onExit,
    required this.onToggleOverview,
  });

  final NavState nav;
  final bool tracking;
  final VoidCallback onExit;
  final VoidCallback onToggleOverview;

  @override
  ConsumerState<CycleNavBottomSheet> createState() =>
      _CycleNavBottomSheetState();
}

class _CycleNavBottomSheetState extends ConsumerState<CycleNavBottomSheet> {
  /// The grade (%) at which the sheet slides to the gradient page, and the one
  /// at which it slides back once the climb is behind.
  static const double _climbGrade = 4;
  static const double _flattenedGrade = 1.5;

  final PageController _controller = PageController();

  /// True while the current page is the gradient page because we switched to
  /// it (not the rider), so we know when to switch back.
  bool _autoOnGradient = false;

  /// True while an automatic page animation runs — page changes during it are
  /// not the rider's, so they do not disable the auto-switch.
  bool _autoAnimating = false;

  /// Set when the rider swipes away during a climb; suppresses the auto-switch
  /// until the climb is behind, so we never fight them.
  bool _riderTookControl = false;

  @override
  void didUpdateWidget(CycleNavBottomSheet old) {
    super.didUpdateWidget(old);
    if (old.nav.traveledMeters != widget.nav.traveledMeters ||
        old.nav.route != widget.nav.route) {
      _maybeAutoSwitch();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _gradientPage {
    final ElevationProfile? profile = widget.nav.route?.elevation;
    if (profile == null || profile.isEmpty) {
      return null;
    }
    // Gradient is the last page (after ride + timing).
    return 2;
  }

  void _maybeAutoSwitch() {
    final int? gradient = _gradientPage;
    if (gradient == null || !_controller.hasClients) {
      return;
    }
    final ElevationProfile profile = widget.nav.route!.elevation;
    final double grade = profile.maxGradeAhead(
      widget.nav.traveledMeters,
      aheadMeters: 250,
    );
    if (grade >= _climbGrade) {
      if (!_autoOnGradient && !_riderTookControl) {
        _autoOnGradient = true;
        unawaitedGoTo(gradient);
      }
    } else if (grade < _flattenedGrade) {
      _riderTookControl = false;
      if (_autoOnGradient) {
        _autoOnGradient = false;
        unawaitedGoTo(0);
      }
    }
  }

  Future<void> unawaitedGoTo(int page) async {
    _autoAnimating = true;
    try {
      await _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _autoAnimating = false;
    }
  }

  void _onPageChanged(int page) {
    if (!_autoAnimating) {
      // The rider moved the board themselves.
      _riderTookControl = _autoOnGradient;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final NavState nav = widget.nav;
    final List<Widget> pages = _pages(context, ref, imperial, nav);
    return NavSheet(
      nav: nav,
      tracking: widget.tracking,
      onExit: widget.onExit,
      onToggleOverview: widget.onToggleOverview,
      initialChildSize: 0.32,
      minChildSize: 0.11,
      maxChildSize: 0.62,
      snapSizes: const <double>[0.11, 0.32, 0.62],
      topPadding: AppSpacing.xl,
      body: NavStatsPager(
        pages: pages,
        controller: _controller,
        onPageChanged: _onPageChanged,
        height: 148,
      ),
    );
  }

  List<Widget> _pages(
    BuildContext context,
    WidgetRef ref,
    bool imperial,
    NavState nav,
  ) {
    final double remaining = (nav.totalMeters - nav.traveledMeters).clamp(
      0,
      double.infinity,
    );
    final double? speedKmh = currentSpeedKmh(ref);
    // Trip statistics are measured from the actual start of the trip, so a
    // reroute (which resets `traveledMeters` to the new route) never restarts
    // the elapsed clock or the covered distance.
    final Duration elapsed = tripElapsed(nav);
    final double tripTraveled = nav.tripTraveledMeters.clamp(
      0,
      double.infinity,
    );
    final double totalDistance = tripTraveled + remaining;
    final double averageKmh = elapsed.inSeconds <= 0
        ? 0
        : (tripTraveled / elapsed.inSeconds) * 3.6;

    final (String, String) traveledText = splitUnit(
      formatDistance(tripTraveled, imperial: imperial, precise: true),
    );
    final (String, String) remainingText = splitUnit(
      formatDistance(remaining, imperial: imperial, precise: true),
    );
    final (String, String) totalText = splitUnit(
      formatDistance(totalDistance, imperial: imperial, precise: true),
    );
    final (String, String) elapsedText = splitUnit(formatDuration(elapsed));
    final (String, String) leftText = splitUnit(formatDuration(nav.remaining));
    final (String, String) speedText = formatSpeed(speedKmh, imperial);
    final (String, String) averageText = formatSpeed(averageKmh, imperial);
    final ElevationProfile profile =
        nav.route?.elevation ?? ElevationProfile.empty;

    return <Widget>[
      NavStatsGrid(
        stats: <NavStat>[
          NavStat(traveledText.$1, traveledText.$2, 'Distance'),
          NavStat(speedText.$1, speedText.$2, 'Speed'),
          NavStat(remainingText.$1, remainingText.$2, 'To end'),
          NavStat(averageText.$1, averageText.$2, 'Average speed'),
        ],
      ),
      NavStatsGrid(
        stats: <NavStat>[
          NavStat(elapsedText.$1, elapsedText.$2, 'Elapsed'),
          NavStat(leftText.$1, leftText.$2, 'Time left'),
          NavStat(arrivalLabel(context, nav.remaining), '', 'Arrives'),
          NavStat(totalText.$1, totalText.$2, 'Total distance'),
        ],
      ),
      if (profile.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: CycleGradientProfile(
            profile: profile,
            currentDistanceMeters: nav.traveledMeters,
            imperial: imperial,
          ),
        ),
    ];
  }
}
