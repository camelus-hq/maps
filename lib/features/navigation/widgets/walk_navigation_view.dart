import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';

/// The pedestrian guidance chrome: a compact top instruction card (the ETA and
/// options live in the shared [NavBottomSheet]).
class WalkNavigationView extends ConsumerWidget {
  const WalkNavigationView({super.key, required this.nav});

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
