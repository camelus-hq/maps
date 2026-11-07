import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';

/// The cycling guidance chrome: a compact top instruction card.
///
/// A bicycle is not bound to road lanes, so there is no lane-guidance strip,
/// and the rider's speed lives in the sheet's ride stats rather than a floating
/// chip. The ETA header and the ride stats live in the cycling sheet
/// ([CycleNavBottomSheet]).
class CycleNavigationView extends ConsumerWidget {
  const CycleNavigationView({super.key, required this.nav});

  final NavState nav;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool imperial = ref.watch(imperialUnitsProvider);
    final NavStyle style = NavStyle.forMode(nav.mode);
    return Positioned(
      top: AppSpacing.sm,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
      child: NavBanner(nav: nav, style: style, imperial: imperial),
    );
  }
}
