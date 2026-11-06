import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../state/navigation.dart';
import '../../../state/settings.dart';
import '../nav_style.dart';
import 'nav_widgets.dart';

/// The public-transport guidance chrome: an indigo instruction card while the
/// same itinerary is followed on the shared map (the ETA and options live in
/// the shared [NavBottomSheet]).
class TransitNavigationView extends ConsumerWidget {
  const TransitNavigationView({super.key, required this.nav});

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
