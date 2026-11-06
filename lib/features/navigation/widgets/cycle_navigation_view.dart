import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/location.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';

/// The cycling guidance chrome: like the car layout but without the regulatory
/// speed-limit sign (only the rider's own speed).
class CycleNavigationView extends ConsumerWidget {
  const CycleNavigationView({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final NavStyle style = NavStyle.forMode(nav.mode);
    final double? speedKmh = _speedKmh(ref);
    final double controlsBottom =
        MediaQuery.sizeOf(context).height * 0.17 + AppSpacing.sm;
    return Stack(
      children: <Widget>[
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          right: AppSpacing.sm,
          child: NavBanner(nav: nav, style: style, imperial: imperial),
        ),
        Positioned(
          left: AppSpacing.md,
          bottom: controlsBottom,
          child: NavSpeedChip(
            limitKmh: null,
            currentKmh: speedKmh,
            imperial: imperial,
          ),
        ),
      ],
    );
  }
}

double? _speedKmh(WidgetRef ref) {
  final double? metersPerSecond = ref
      .watch(locationTrackerProvider)
      .fix
      ?.speedMetersPerSecond;
  if (metersPerSecond == null || !metersPerSecond.isFinite) {
    return null;
  }
  return metersPerSecond * 3.6;
}
